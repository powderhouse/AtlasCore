//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

import Foundation

public class GitAnnex {
    
    let remoteName = "atlasS3"
    public let directory: URL!
    var credentials: Credentials!
    
    var s3Path: String {
        get {
            return "https://s3.amazonaws.com/atlas-\(credentials.username)"
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
        let info = run("info", arguments: [remoteName])
        
        if info.contains("remote: \(remoteName)") {
            _ = run("enableremote", arguments: [remoteName])
            sync()
            return
        }
        
        _ = run("initremote", arguments: [remoteName, "type=S3", "encryption=none",
                                          "bucket=atlas-\(credentials.username)", "exporttree=yes",
                                          "public=yes", "encryption=none"
            ]
        )
        
        _ = run("enableremote", arguments: [remoteName])
        
        _ = run("export", arguments: ["--tracking", "master", "--to", remoteName])
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
        
        return Glue.runProcess("git",
                               arguments: ["annex"] + fullArguments,
                               environment_variables: credentialed_environment_variables,
                               currentDirectory: directory
        )
    }
    
    public func initDirectory() -> Bool {
        let result = run("init")
        return result.contains("ok")
    }

    public func add(_ filter: String=".") -> Bool {
        let result = run("add", arguments: [filter])
        return result.contains("ok")
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
