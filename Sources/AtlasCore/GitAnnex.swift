//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

import Foundation

public class GitAnnex {
    
    public static let remoteName = "atlasS3"
    public static let groupName = "powderhouse-atlas"
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
    }
    
    public func initialize() -> Result {
        var result = Result()
        
        if !installed() {
            let installResult = install()
            if !installResult.success {
                return installResult
            }
            result.mergeIn(installResult)
        }
        
        if !info().contains(GitAnnex.remoteName) {
            let directoryResult = initDirectory()
            result.mergeIn(directoryResult)
            
            if credentials.s3AccessKey != "test" {
                let awsResult = initializeAWS()
                result.mergeIn(awsResult)
            }
            
            let s3Result = initializeS3()
            result.mergeIn(s3Result)
        }
        
        return result
    }
    
    public func installed() -> Bool {
        let info = Glue.runProcess(
            "brew",
            arguments: ["info", "git-annex"],
            currentDirectory: directory
        )
        return !info.contains("Not installed")
    }
    
    public func install() -> Result {
        let output = Glue.runProcess(
            "brew",
            arguments: ["install", "git-annex"],
            currentDirectory: directory
        )
        if !output.contains("start git-annex") {
            return Result(
                success: false,
                messages: ["Failed to install Git Annex"]
            )
        }
        return Result()
    }
    
    public func initializeAWS() -> Result {
        guard credentials.complete() else {
            return Result(
                success: false,
                messages: ["Improper credentials for initializing AWS"]
            )
        }
        
        var result = Result()
        
        let awsCredentials = [
            "AWS_ACCESS_KEY_ID": credentials.s3AccessKey!,
            "AWS_SECRET_ACCESS_KEY": credentials.s3SecretAccessKey!
        ]
        
        let userOutput = Glue.runProcessError(
            "aws",
            arguments: [
                "iam",
                "create-user",
                "--path", "/\(AtlasCore.repositoryName)/",
                "--user-name", credentials.username
            ],
            environment_variables: awsCredentials
        )
        result.messages.append(userOutput)
        
        let credentialsOutput = Glue.runProcessError(
            "aws",
            arguments: [
                "iam",
                "create-access-key",
                "--user-name", credentials.username
            ],
            environment_variables: awsCredentials
        )
        
        result.messages.append(credentialsOutput)
        
        if let credentialsData = credentialsOutput.data(using: .utf8) {
            do {
                if let credentialsDict = try JSONSerialization.jsonObject(with: credentialsData, options: []) as? [String: [String: String]] {
                    if let accessKey = credentialsDict["AccessKey"] {
                        credentials.setS3AccessKey(accessKey["AccessKeyId"])
                        credentials.setS3SecretAccessKey(accessKey["SecretAccessKey"])
                        credentials.save()
                    }
                }
            } catch {
                result.success = false
                result.messages.append("Failed to capture AWS credentials: \(error)")
            }
        }
        
        let iamUserCredentials = [
            "AWS_ACCESS_KEY_ID": credentials.s3AccessKey!,
            "AWS_SECRET_ACCESS_KEY": credentials.s3SecretAccessKey!
        ]
        
        let groupOutput = Glue.runProcessError(
            "aws",
            arguments: [
                "iam",
                "add-user-to-group",
                "--group-name", GitAnnex.groupName,
                "--user-name", credentials.username
            ],
            environment_variables: awsCredentials
        )
        result.messages.append(groupOutput)
        
        var awsReady = false
        repeat {
            sleep(1)
            let keysOutput = Glue.runProcessError(
                "aws",
                arguments: [
                    "iam",
                    "list-access-keys"
                ],
                environment_variables: iamUserCredentials
            )
            let groupsOutput = Glue.runProcessError(
                "aws",
                arguments: [
                    "iam",
                    "list-groups-for-user",
                    "--user-name", credentials.username
                ],
                environment_variables: awsCredentials
            )
            
            awsReady = (
                !keysOutput.contains("InvalidClientTokenId") &&
                    groupsOutput.contains(GitAnnex.groupName)
            )
        } while !awsReady
        
        return result
    }
    
    public func initializeS3() -> Result {
        var result = Result()
        let info = run("info", arguments: [GitAnnex.remoteName])
        
        if info.contains("remote: \(GitAnnex.remoteName)") {
            let output = run("enableremote", arguments: [GitAnnex.remoteName, "publicurl=\(s3Path)"])
            if !output.contains("recording state") {
                result.success = false
                result.messages += ["Unable to enable Git Annex remote.", output]
            }
            sync()
            return result
        }
        
        var initArguments = [
            GitAnnex.remoteName,
            "type=S3",
            "encryption=none",
            "bucket=\(GitAnnex.groupName)-\(credentials.username)",
            "exporttree=yes",
            "public=yes",
            "publicurl=\(s3Path)"
        ]
        
        if credentials.s3AccessKey == "test" {
            let httpOutput = run("config", arguments: [
                "--set",
                "annex.security.allowed-http-addresses",
                "all"
                ])
            result.messages.append(httpOutput)
            initArguments.append("host=localhost")
            initArguments.append("port=4572")
            initArguments.append("requeststyle=path")
            //            initArguments.append("--debug")
        }
        
        let successText = "recording state"
        let initOutput = run("initremote", arguments: initArguments)
        if !initOutput.contains(successText) {
            result.success = false
            result.messages += ["Unable to initialize Git Annex remote.", initOutput]
            return result
        }
        
        let enableOutput = run("enableremote", arguments: [GitAnnex.remoteName, "publicurl=\(s3Path)"])
        if !enableOutput.contains(successText) {
            result.success = false
            result.messages += ["Unable to enable Git Annex remote.", enableOutput]
            return result
        }
        
        let exportOutput = run("export", arguments: ["--tracking", "master", "--to", GitAnnex.remoteName])
        if !exportOutput.contains(successText) {
            result.success = false
            result.messages += ["Git Annex is unable to track master.", exportOutput]
        }
        
        return result
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
        
        return Glue.runProcessError("git-annex",
                                    arguments: fullArguments,
                                    environment_variables: credentialed_environment_variables,
                                    currentDirectory: directory
        )
    }
    
    public func initDirectory() -> Result {
        var result = Result()
        let output = run("init")
        if !output.contains("recording state") {
            result.success = false
            result.messages.append("Failed to initialize Git Annex")
        }
        result.messages.append(output)
        return result
    }
    
    public func add(_ filter: String=".") -> Result {
        var result = Result()
        let output = run("add", arguments: [filter])
        if !output.contains("ok") {
            result.success = false
            result.messages.append("Failed to add files")
        }
        result.messages.append(output)
        return result
    }
    
    public func info() -> String {
        return run("info")
    }
    
    public func deleteFile(_ filePath: String) -> Result {
        let output = run("drop", arguments: ["--force", filePath])
        if output.contains("failed") {
            return Result(
                success: false,
                messages: ["Git Annex failed to drop: \(filePath)", output]
            )
        }
        return Result()
    }
    
    public func sync() {
        DispatchQueue.global(qos: .background).async {
            _ = self.run("sync")
        }
    }
    
}
