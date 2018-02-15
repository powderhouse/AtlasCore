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
    
    public init(_ username: String, password: String?=nil, token: String?=nil) {
        self.username = username
        self.password = password
        self.token = token
    }

    public func save(_ directory: URL) {
        guard token != nil else {
            printCredentials("No token provided: \(username)")
            return
        }
        
        do {
            let jsonCredentials = try JSONSerialization.data(
                withJSONObject: [
                    "username": username,
                    "token": token!
                ],
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
    
    public func setAuthenticationToken(_ gitHub: GitHub) {
        let listArguments = [
            "-u", "\(username):\(password!)",
            "https://api.github.com/authorizations"
        ]
        
        if let list = gitHub.api(listArguments) {
            for item in list {
                if (item["note"] as? String) == "Atlas Token" {
                    let deleteAuthArguments = [
                        "-u", "\(username):\(password!)",
                        "-X", "DELETE",
                        "https://api.github.com/authorizations/\(item["id"]!)"
                    ]
                    _ = gitHub.api(deleteAuthArguments)
                }
            }
        }
        
        let authArguments = [
            "-u", "\(username):\(password!)",
            "-X", "POST",
            "https://api.github.com/authorizations",
            "-d", "{\"scopes\":[\"repo\", \"delete_repo\"], \"note\":\"Atlas Token\"}"
        ]
        
        if let authentication = gitHub.api(authArguments) {
            guard authentication[0]["token"] != nil else {
                printCredentials("Failed GitHub Authentication: \(authentication)")
                return
            }
            
            self.token = authentication[0]["token"] as? String
        }
    }
    
    public class func retrieve(_ baseDirectory: URL) -> [Credentials] {
        let path = baseDirectory.appendingPathComponent(filename)
        var json: String
        do {
            json = try String(contentsOf: path, encoding: .utf8)
        }
        catch {
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
                                token: token
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
    
    class func printCredentials(_ message: String) {
        print("CREDENTIALS: \(message)")
    }
    
    func printCredentials(_ message: String) {
        Credentials.printCredentials(message)
    }
    
}
