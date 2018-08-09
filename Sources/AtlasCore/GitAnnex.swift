//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

import Foundation

public class GitAnnex {
    
    public static let remoteName = "atlasS3"
    public let directory: URL!
    var credentials: Credentials!
    
    public var s3Bucket: String {
        get {
            return "atlas-\(credentials.username)"
        }
    }
    public var s3Path: String {
        get {
            return "https://s3.amazonaws.com/\(s3Bucket)"
        }
    }

    public init(_ directory: URL, credentials: Credentials) {
        self.directory = directory
        self.credentials = credentials
        
        if !installed() {
            _ = install()
        }
        
        _ = initDirectory()
        initializeS3()
    }
    
    public func installed() -> Bool {
        let info = Glue.runProcess("brew", arguments: ["info", "git-annex"])
        return !info.contains("Not installed")
    }
    
    public func install() -> Bool {
        let result = Glue.runProcess("brew", arguments: ["install", "git-annex"])
        return result.contains("start git-annex")
    }
    
    public func initializeS3() {
        let info = run("info", arguments: [GitAnnex.remoteName])
        
        if info.contains("remote: \(GitAnnex.remoteName)") {
            _ = run("enableremote", arguments: [GitAnnex.remoteName, "publicurl=\(s3Path)"])
            sync()
            return
        }
        
        var initArguments = [
            GitAnnex.remoteName,
            "type=S3",
            "encryption=none",
            "bucket=atlas-\(credentials.username)",
            "exporttree=yes",
            "public=yes",
            "publicurl=\(s3Path)"
        ]
        
        if credentials.s3AccessKey == "test" {
            initArguments.append("host=localhost")
            initArguments.append("port=4572")
            initArguments.append("requeststyle=path")
        }
        
        _ = run("initremote", arguments: initArguments)
        
        _ = run("enableremote", arguments: [GitAnnex.remoteName, "publicurl=\(s3Path)"])
        
        _ = run("export", arguments: ["--tracking", "master", "--to", GitAnnex.remoteName])
    }
    
    func buildArguments(_ command: String, additionalArguments:[String]=[]) -> [String] {
        return [command] + additionalArguments
    }
    
    func run(_ command: String, arguments: [String]=[], environment_variables:[String:String]=[:]) -> String {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        var credentialed_environment_variables = environment_variables
        credentialed_environment_variables["AWS_ACCESS_KEY_ID"] = credentials.s3AccessKey ?? ""
        credentialed_environment_variables["AWS_SECRET_ACCESS_KEY"] = credentials.s3SecretAccessKey ?? ""
        
        return Glue.runProcessError("git",
                               arguments: ["annex"] + fullArguments,
                               environment_variables: credentialed_environment_variables,
                               currentDirectory: directory
        )
    }
    
    public func initDirectory() -> Bool {
        let result = run("init")
        return result.contains("ok")
    }

    public func add(_ filter: String=".") -> String {
        return run("add", arguments: [filter])
    }
    
    public func info() -> String {
        return run("info")
    }

    public func deleteFile(_ filePath: String) -> String {
        return run("drop", arguments: ["--force", "file"])
    }

    public func status() -> String {
        return run("status", arguments: ["--short"])
    }

    public func sync() {
        DispatchQueue.global(qos: .background).async {
            _ = self.run("sync")
        }
    }
    
}
