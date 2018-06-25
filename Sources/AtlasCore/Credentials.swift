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
    public let password: String?
    public var token: String?

    public let s3AccessKey: String?
    public let s3SecretAccessKey: String?

    public init(_ username: String,
        password: String?=nil,
        token: String?=nil,
        s3AccessKey: String?=nil,
        s3SecretAccessKey: String?=nil
    ) {
        self.username = username
        self.password = password
        self.token = token

        self.s3AccessKey = s3AccessKey
        self.s3SecretAccessKey = s3SecretAccessKey
    }
    
    public func sync(_ credentials: Credentials) {
        if self.username == credentials.username {
            if self.token == nil {
                self.token = credentials.token
            }
        }
    }
    
    public func complete() -> Bool {
        guard s3AccessKey != nil else { return false }
        guard s3SecretAccessKey != nil else { return false }

        if password == nil && token == nil { return false }
        
        return true
    }

    public func save(_ directory: URL) {
        guard token != nil else {
            printCredentials("No token provided: \(username)")
            return
        }
        
        do {
            var credentialsHash: [String: String] = [
                "username": username,
                "token": token!
            ]
            
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
            } catch {
                printCredentials("Failed to save credentials.json: \(error)")
            }
        } catch {
            printCredentials("Failed to convert credentials to json")
        }
    }
    
    public func setAuthenticationToken(token: String?) {
        self.token = token
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
                        if let token = credentialsDict["token"] {
                            return [Credentials(
                                username,
                                password: nil,
                                token: token,
                                s3AccessKey: credentialsDict["s3AccessKey"],
                                s3SecretAccessKey: credentialsDict["s3SecretAccessKey"]
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
    
    public class func delete(_ directory: URL) {
        let url = directory.appendingPathComponent(filename)
        FileSystem.deleteDirectory(url)
    }
    
    class func printCredentials(_ message: String) {
        print("CREDENTIALS: \(message)")
    }
    
    func printCredentials(_ message: String) {
        Credentials.printCredentials(message)
    }
    
}
