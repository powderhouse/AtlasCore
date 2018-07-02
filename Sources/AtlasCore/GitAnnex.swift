//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

//Add one file first.
//git annex init
//export AWS_ACCESS_KEY_ID="AKIAIZOX3I3MWEZIRR2Q"
//export AWS_SECRET_ACCESS_KEY="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"
//git annex initremote publics3 type=S3 encryption=none bucket=atlas-jaredcosulich exporttree=yes public=yes encryption=none
//git annex export --tracking master --to publics3
//git annex add .
//git commit -am "blah blah"
//git push
//git annex sync --content

import Foundation

public class GitAnnex {
    
    public let directory: URL!
    
    public init(_ directory: URL, credentials: Credentials) {
        self.directory = directory
        
        if !installed() {
            _ = install()
        }
        
        _ = initDirectory()
        initializeS3(credentials)
    }
    
    public func installed() -> Bool {
        let info = Glue.runProcess("brew", arguments: ["info", "git-annex"])
        return !info.contains("Not installed")
    }
    
    public func install() -> Bool {
        let result = Glue.runProcess("brew", arguments: ["install", "git-annex"])
        return result.contains("start git-annex")
    }
    
    public func initializeS3(_ credentials: Credentials) {
        if let s3AccessKey = credentials.s3AccessKey {
            if let s3SecretAccessKey = credentials.s3SecretAccessKey {
                _ = run("initremote", arguments: ["atlasS3", "type=S3", "encryption=none",
                    "bucket=atlas-\(credentials.username)", "exporttree=yes",
                    "public=yes", "encryption=none"
                    ], environment_variables: ["AWS_ACCESS_KEY_ID": s3AccessKey, "AWS_SECRET_ACCESS_KEY":  s3SecretAccessKey]
                )
                _ = run("export", arguments: ["--tracking", "master", "--to", "atlasS3"])
            }
        }
    }
    
    func buildArguments(_ command: String, additionalArguments:[String]=[]) -> [String] {
        return [command] + additionalArguments
    }
    
    func run(_ command: String, arguments: [String]=[], environment_variables:[String:String]?=nil) -> String {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        
        return Glue.runProcess("git",
                               arguments: ["annex"] + fullArguments,
                               environment_variables: environment_variables,
                               currentDirectory: directory
        )
    }
    
    public func initDirectory() -> Bool {
        let result = run("init")
        return result.contains("ok")
    }

    public func add(_ filter: String=".") -> Bool {
        let result = run("add", arguments: [filter])
        return result.contains("added")
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
        _ = run("sync")
    }
    
}
