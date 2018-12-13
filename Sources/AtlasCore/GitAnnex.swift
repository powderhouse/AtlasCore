//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

import Foundation
import SwiftAWSIam
import SwiftAWSS3

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
        
        var initialized = false
        
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
            
            initialized = true
        } else {
            let enableOutput = enableRemote()
            result.mergeIn(enableOutput)

            let configureOutput = configure()
            result.mergeIn(configureOutput)
            
            let wantedOutput = wanted()
            result.mergeIn(wantedOutput)

            sync(result, completed: { (_ result: Result) -> Void in
                var result = result
                let exportOutput = self.exportTracking()
                result.mergeIn(exportOutput)
                
                if self.files() == nil {
                    result.success = false
                    result.add("Unable to sync with S3. Please check credentials.")
                }
                
                initialized = true
            })
        }
        
        while !initialized {
            sleep(2)
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
                    result.add("Invalid AWS credentials")
                    result.add(error.localizedDescription)
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
            "versioning=yes",
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
        
        result.mergeIn(wanted())
        
        result.mergeIn(exportTracking())
        
        return result
    }
    
    func buildArguments(_ command: String, additionalArguments:[String]=[]) -> [String] {
        return [command] + additionalArguments
    }
    
    func credential_environment_variables(_ environment_variables:[String:String]=[:]) -> [String:String] {
        var credentialed_environment_variables = environment_variables
        credentialed_environment_variables["AWS_ACCESS_KEY_ID"] = credentials.s3AccessKey ?? ""
        credentialed_environment_variables["AWS_SECRET_ACCESS_KEY"] = credentials.s3SecretAccessKey ?? ""
        return credentialed_environment_variables
    }
    
    func run(_ command: String, arguments: [String]=[], environment_variables:[String:String]=[:]) -> String {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        
        let credentialed_environment_variables = credential_environment_variables(environment_variables)
        
        return Glue.runProcessError("git-annex",
                                    arguments: fullArguments,
                                    environment_variables: credentialed_environment_variables,
                                    currentDirectory: directory
        )
    }
    
    func runLong(_ command: String, arguments: [String]=[], environment_variables:[String:String]=[:], result: Result, info: String?=nil, completed: ((Process) -> Void)?=nil) {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        
        let credentialed_environment_variables = credential_environment_variables(environment_variables)
        
        Glue.runProcessErrorAndLog("git-annex",
                                   arguments: fullArguments,
                                   environment_variables: credentialed_environment_variables,
                                   currentDirectory: directory,
                                   log: self.logSync(result, info: info),
                                   completed: completed
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
        let output = run("enableremote", arguments: [GitAnnex.remoteName, "versioning=yes"])
        if !output.contains(GitAnnex.successText) {
            result.success = false
            result.add(["Unable to enable Git Annex remote.", output])
        }
        
        return result
    }
    
    func wanted() -> Result {
        var result = Result()
        let wantedOutput = run("wanted", arguments: [".", "standard"])
        let groupOutput = run("group", arguments: [".", "source"])
        result.add(wantedOutput)
        result.add(groupOutput)
        return result
    }
    
    func exportTracking() -> Result {
        var result = Result()
        let output = run("export", arguments: ["--tracking", "master", "--to", GitAnnex.remoteName])
        if !output.contains(GitAnnex.successText) {
            result.success = false
            result.add(["Git Annex is unable to track master.", output])
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
    
    public func files() -> [String]? {
        var s3Files: [String] = []
        
        var endpoint: String? = nil
        if credentials.s3AccessKey == "test" {
            endpoint = "http://localhost:4572"
        }
        
        let s3 = S3(accessKeyId: credentials.s3AccessKey, secretAccessKey: credentials.s3SecretAccessKey, endpoint: endpoint)
        
        do {
            let objects = try s3.listObjectsV2(S3.ListObjectsV2Request(bucket: s3Bucket))
            for object in objects.contents! {
                if let key = object.key {
                    s3Files.append(key)
                }
            }
        } catch {
            print("S3 FILES ERROR: \(error)")
            return nil
        }
        
        return s3Files
    }
    
    public func sync(_ existingResult: Result?=nil, completed: ((_ result: Result) -> Void)?=nil) {
        let result = existingResult ?? Result()
        
        _ = info()
        
        DispatchQueue.global(qos: .background).async {
            self.runLong("sync",
                         arguments: ["--content"],
                         result: result,
                         completed: { process in
                            completed?(result)
                         }
            )
        }
    }
    
    func logSync(_ existingResult: Result?=nil, info: String?=nil) -> (_ fileHandle: FileHandle) -> Void {
        var result = existingResult ?? Result()
        var blankLineCount = 0
        let log: (_ fileHandle: FileHandle) -> Void  = { fileHandle in
            if let line = String(data: fileHandle.availableData, encoding: String.Encoding.utf8) {
                if line.count > 0 {
                    if let info = info {
                        result.add(info + " - " + line)
                    } else {
                        result.add(line)
                    }
                } else {
                    blankLineCount += 1
                    if blankLineCount > 30 {
                        fileHandle.closeFile()
                        fileHandle.readabilityHandler = nil
                    }
                }
            } else {
                result.add("Error decoding data: \(fileHandle.availableData)")
            }
        }
        return log
    }
    
}
