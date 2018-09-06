//
//  Credentials.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/14/18.
//

import Foundation

public class Credentials {
    static let filename = "credentials.json"

    public let username: String
    public let email: String
    public let password: String?
    public var token: String?
    public var remotePath: String?
    
    public var s3AccessKey: String?
    public var s3SecretAccessKey: String?
    
    public var directory: URL?

    public init(_ username: String,
        email: String,
        password: String?=nil,
        token: String?=nil,
        remotePath: String?=nil,
        s3AccessKey: String?=nil,
        s3SecretAccessKey: String?=nil,
        directory: URL?=nil
    ) {
        self.username = username
        self.email = email
        self.password = password
        self.token = token
        self.remotePath = remotePath
        self.directory = directory

        if s3AccessKey?.count ?? 0 > 0 {
            self.s3AccessKey = s3AccessKey
        }
        
        if s3SecretAccessKey?.count ?? 0 > 0 {
            self.s3SecretAccessKey = s3SecretAccessKey
        }
    }
    
    public func sync(_ credentials: Credentials) {
        if self.username == credentials.username {
            if self.token == nil {
                self.token = credentials.token
            }
            if self.remotePath == nil {
                self.remotePath = credentials.remotePath
            }
        }
    }
    
    public func complete() -> Bool {
        guard s3AccessKey != nil else { return false }
        guard s3SecretAccessKey != nil else { return false }

        if password == nil && token == nil && remotePath == nil { return false }
        
        return true
    }

    public func save() {
        guard token != nil || remotePath != nil else {
            printCredentials("No token or remote path provided: \(username)")
            return
        }
        
        do {
            var credentialsHash: [String: String] = [
                "username": username,
                "email": email
            ]
            
            if token != nil {
                credentialsHash["token"] = token
            }
            
            if remotePath != nil {
                credentialsHash["remotePath"] = remotePath
            }
            
            if s3AccessKey != nil {
                credentialsHash["s3AccessKey"] = s3AccessKey
            }

            if s3SecretAccessKey != nil {
                credentialsHash["s3SecretAccessKey"] = s3SecretAccessKey
            }

            let jsonCredentials = try JSONSerialization.data(
                withJSONObject: credentialsHash,
                options: .prettyPrinted
            )
            
            do {
                if let directory = directory {
                    let filename = directory.appendingPathComponent(Credentials.filename)
                    
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: filename.path) {
                        do {
                            try fileManager.removeItem(at: filename)
                        } catch {
                            printCredentials("Failed to delete credentials.json: \(error)")
                        }
                    }
                    
                    try jsonCredentials.write(to: filename)
                } else {
                    printCredentials("Failed to save credentials.json: No user directory provided")
                }
            } catch {
                printCredentials("Failed to save credentials.json: \(error)")
            }
        } catch {
            printCredentials("Failed to convert credentials to json")
        }
    }
    
    public func setDirectory(_ directory: URL) {
        self.directory = directory
    }
    
    public func setAuthenticationToken(_ token: String?) {
        self.token = token
    }

    public func setRemotePath(_ path: String?) {
        self.remotePath = path
    }

    public func setS3AccessKey(_ s3AccessKey: String?) {
        self.s3AccessKey = s3AccessKey
    }

    public func setS3SecretAccessKey(_ s3SecretAccessKey: String?) {
        self.s3SecretAccessKey = s3SecretAccessKey
    }

    public class func retrieve(_ baseDirectory: URL) -> [Credentials] {
        let path = baseDirectory.appendingPathComponent(filename)
        var json: String
        do {
            json = try String(contentsOf: path, encoding: .utf8)
        } catch {
            printCredentials("Not Found")
            return []
        }
        
        if let data = json.data(using: .utf8) {
            do {
                if let credentialsDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    if let username = credentialsDict["username"] {
                        if let email = credentialsDict["email"] {
                            return [Credentials(
                                username,
                                email: email,
                                password: nil,
                                token: credentialsDict["token"],
                                remotePath: credentialsDict["remotePath"],
                                s3AccessKey: credentialsDict["s3AccessKey"],
                                s3SecretAccessKey: credentialsDict["s3SecretAccessKey"],
                                directory: baseDirectory
                            )]
                        }
                    }
                }
            } catch {
                printCredentials("Loading Error")
                printCredentials(error.localizedDescription)
            }
        }
        return []
    }
    
    public class func delete(_ directory: URL) -> Result {
        let url = directory.appendingPathComponent(filename)
        return FileSystem.deleteDirectory(url)
    }
    
    class func printCredentials(_ message: String) {
        print("CREDENTIALS: \(message)")
    }
    
    func printCredentials(_ message: String) {
        Credentials.printCredentials(message)
    }
    
}
