//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

import Foundation
import SwiftAWSIam

public class GitAnnex {
    
    public static let remoteName = "atlasS3"
    public static let groupName = "powderhouse-atlas"
    public static let successText = "recording state"
    public let directory: URL!
    var credentials: Credentials!
    
    public var s3Bucket: String {
        get {
            return "\(GitAnnex.groupName)-\(credentials.username)"
        }
    }
    public var s3Path: String {
        get {
            return "https://s3.amazonaws.com/\(s3Bucket)/"
        }
    }
    
    public init(_ directory: URL, credentials: Credentials) {
        self.directory = directory
        self.credentials = credentials
    }
    
    public func initialize(_ existingResult: Result?=nil) -> Result {
        var result = existingResult ?? Result()
        
        result.add("Checking Git Annex installation.")
        
        if !info().contains(GitAnnex.remoteName) {
            let directoryResult = initDirectory()
            result.mergeIn(directoryResult)
            
            if credentials.s3AccessKey != "test" {
                let awsResult = initializeAWS(result)
                result.mergeIn(awsResult)
            }
            
            if result.success {
                result.add("Initializing S3")
                let s3Result = initializeS3(result)
                result.mergeIn(s3Result)
            }
        } else {
            result.mergeIn(enableRemote())
            result.mergeIn(configure())
            return result
        }
        
        return result
    }
    
    public func initializeAWS(_ existingResult: Result?=nil) -> Result {
        var result = existingResult ?? Result()
        
        guard credentials.complete() else {
            result.success = false
            result.add("Improper credentials for initializing AWS")
            return result
        }
        
        let iam = Iam(accessKeyId: credentials.s3AccessKey, secretAccessKey: credentials.s3SecretAccessKey)
        
        result.add("Checking AWS IAM for existing user.")
        
        let user = try? iam.getUser(Iam.GetUserRequest(userName: credentials.username))
        
        if user == nil {
            do {
                _ = try iam.getAccountAuthorizationDetails(Iam.GetAccountAuthorizationDetailsRequest())
            } catch {
                if "\(error)".contains(credentials.username) {
                    result.add("IAM user already initialized.")
                } else {
                    result.success = false
                    result.add("Invalid AWS credentials: \(error)")
                }
                return result
            }
            
            result.add("Creating AWS IAM user.")
            
            do {
                _ = try iam.createUser(Iam.CreateUserRequest(
                    userName: credentials.username,
                    path: "/\(AtlasCore.repositoryName)/"
                ))
            } catch {
                result.success = false
                result.add("Failed to create IAM user: \(error)")
            }
        }
        
        do {
            let accessKey = try iam.createAccessKey(Iam.CreateAccessKeyRequest(
                userName: credentials.username
            )).accessKey
            
            credentials.setS3AccessKey(accessKey.accessKeyId)
            credentials.setS3SecretAccessKey(accessKey.secretAccessKey)
            credentials.save()
        } catch {
            result.success = false
            result.add("Failed to create IAM user access key: \(error)")
        }
        
        do {
            try iam.addUserToGroup(Iam.AddUserToGroupRequest(
                userName: credentials.username,
                groupName: GitAnnex.groupName
            ))
        } catch {
            result.success = false
            result.add("Failed to add IAM user to group: \(error)")
        }
        
        return result
    }
    
    public func initializeS3(_ existingResult: Result?=nil) -> Result {
        var result = existingResult ?? Result()
        let info = run("info", arguments: [GitAnnex.remoteName])
        
        if info.contains("remote: \(GitAnnex.remoteName)") {
            result.mergeIn(enableRemote())
            sync()
            return result
        }
        
        var initArguments = [
            GitAnnex.remoteName,
            "type=S3",
            "encryption=none",
            "bucket=\(s3Bucket)",
            "exporttree=yes",
            "public=yes",
            "publicurl=\(s3Path)"
        ]
        
        if credentials.s3AccessKey == "test" {
            result.mergeIn(configure())
            initArguments.append("host=localhost")
            initArguments.append("port=4572")
            initArguments.append("requeststyle=path")
            //            initArguments.append("--debug")
        }
        
        var initOutput: String
        var tries = 0
        repeat {
            sleep(1)
            tries += 1
            initOutput = run("initremote", arguments: initArguments)
            
            if initOutput.contains("git-annex: Cannot reuse this bucket.") {
                initOutput = enableRemote().messages.first ?? ""
            }
            
            if tries % 2 == 0 && !initOutput.contains(GitAnnex.successText) {
                result.add("Waiting for AWS IAM to sync.")
            }
        } while !initOutput.contains(GitAnnex.successText) && tries < 30
        
        if !initOutput.contains(GitAnnex.successText) {
            result.success = false
            result.add(["Unable to initialize Git Annex remote.", initOutput])
            return result
        }
        
        result.mergeIn(enableRemote())
        guard result.success else {
            return result
        }
        
        let exportOutput = run("export", arguments: ["--tracking", "master", "--to", GitAnnex.remoteName])
        if !exportOutput.contains(GitAnnex.successText) {
            result.success = false
            result.add(["Git Annex is unable to track master.", exportOutput])
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
    
    func configure() -> Result {
        var result = Result()
        if credentials.s3AccessKey == "test" {
            let httpOutput = run("config", arguments: [
                "--set",
                "annex.security.allowed-http-addresses",
                "all"
                ])
            result.add(httpOutput)
        }
        return result
    }
    
    func enableRemote() -> Result {
        var result = Result()
        //            let output = run("enableremote", arguments: [GitAnnex.remoteName, "publicurl=\(s3Path)"])
        let output = run("enableremote", arguments: [GitAnnex.remoteName])
        if !output.contains(GitAnnex.successText) {
            result.success = false
            result.add(["Unable to enable Git Annex remote.", output])
        }

        return result
    }
    
    public func initDirectory() -> Result {
        var result = Result()
        let output = run("init")
        if !output.contains(GitAnnex.successText) {
            result.success = false
            result.add("Failed to initialize Git Annex: \(output)")
        }
        result.add(output)
        return result
    }
    
    public func add(_ filter: String=".") -> Result {
        var result = Result()
        let output = run("add", arguments: [filter])
        if output.count > 0 && !output.contains("ok") {
            result.success = false
            result.add(["Failed to add files", output])
        }
        result.add(output)
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
    
    public func sync(_ existingResult: Result?=nil, completed: (() -> Void)?=nil) {
        let result = existingResult ?? Result()
        
        DispatchQueue.global(qos: .background).async {
            
            let credentialed_environment_variables = [
                "AWS_ACCESS_KEY_ID": self.credentials.s3AccessKey ?? "",
                "AWS_SECRET_ACCESS_KEY": self.credentials.s3SecretAccessKey ?? ""
            ]
            
            Glue.runProcessErrorAndLog(
                "git-annex",
                arguments: ["sync", "--content"],
                environment_variables: credentialed_environment_variables,
                currentDirectory: self.directory,
                log: self.logSync(result, completed: {
                    Glue.runProcessErrorAndLog(
                        "git-annex",
                        arguments: ["get", "--json", "--json-progress", "--json-error-messages"],
                        environment_variables: credentialed_environment_variables,
                        currentDirectory: self.directory,
                        log: self.logSync(result, completed: {
                            if completed != nil {
                                completed!()
                            }
                        })
                    )
                })
            )

        }
    }
    
    func logSync(_ existingResult: Result?=nil, completed: (() -> Void)?=nil) -> (_ fileHandle: FileHandle) -> Void {
        var result = existingResult ?? Result()
        var blankLineCount = 0
        let log: (_ fileHandle: FileHandle) -> Void  = { fileHandle in
            if let line = String(data: fileHandle.availableData, encoding: String.Encoding.utf8) {
                if line.count > 0 {
                    result.add(line)
                } else {
                    blankLineCount += 1
                    if blankLineCount > 30 {
                        fileHandle.closeFile()
                        fileHandle.readabilityHandler = nil
                        
                        if completed != nil {
                            completed!()
                        }
                    }
                }
            } else {
                result.add("Error decoding data: \(fileHandle.availableData)")
            }
        }
        return log
    }
    
}
