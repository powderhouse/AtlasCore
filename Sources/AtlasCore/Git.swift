//
//  Git.swift
//  AtlasCorePackageDescription
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public struct Credentials {
    public let username: String
    public let password: String?
    public var token: String?
    
    public init(_ username: String, password: String?=nil, token: String?=nil) {
        self.username = username
        self.password = password
        self.token = token
    }
}

public class Git {
    
    var directory: URL!
    var repositoryName: String
    
    static let credentialsFilename = "github.json"
    static let gitIgnore = [
        "DS_Store",
        "github.json"
    ]
    
    var credentials: Credentials!
    
    public var atlasProcessFactory: AtlasProcessFactory!
    
    
    public init?(_ directory: URL, credentials: Credentials, processFactory: AtlasProcessFactory?=nil) {
        self.directory = directory
        self.credentials = credentials
        self.atlasProcessFactory = processFactory ?? ProcessFactory()
        
        self.repositoryName = directory.lastPathComponent
        
        syncCredentials(credentials)
        saveCredentials(self.credentials)
        
        if self.credentials.token == nil {
            return nil
        }
    }
    
    public func saveCredentials(_ credentials: Credentials) {
        guard credentials.token != nil else {
            printGit("No token provided: \(credentials)")
            return
        }
        
        do {
            let jsonCredentials = try JSONSerialization.data(
                withJSONObject: [
                    "username": credentials.username,
                    "token": credentials.token!
                ],
                options: .prettyPrinted
            )
            
            do {
                let filename = directory.appendingPathComponent(Git.credentialsFilename)
                
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: filename.path) {
                    do {
                        try fileManager.removeItem(at: filename)
                    } catch {
                        printGit("Failed to delete github.json: \(error)")
                    }
                }
                
                try jsonCredentials.write(to: filename)
            } catch {
                printGit("Failed to save github.json: \(error)")
            }
        } catch {
            printGit("Failed to convert credentials to json")
        }
    }
    
    func syncCredentials(_ newCredentials: Credentials) {
        guard newCredentials.token == nil else {
            self.credentials = newCredentials
            return
        }
        
        var credentials = newCredentials
        let existingCredentials = Git.getCredentials(directory)
        
        if credentials.username == existingCredentials?.username {
            credentials.token = existingCredentials?.token
        }
        
        if credentials.token == nil && credentials.password != nil {
            credentials.token = getAuthenticationToken(credentials)
        }
        
        self.credentials = credentials
    }
    
    public class func getCredentials(_ baseDirectory: URL) -> Credentials? {
        let path = baseDirectory.appendingPathComponent(credentialsFilename)
        var json: String
        do {
            json = try String(contentsOf: path, encoding: .utf8)
        }
        catch {
            printGit("GitHub Credentials Not Found")
            return nil
        }
        
        if let data = json.data(using: .utf8) {
            do {
                if let credentialsDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    if let username = credentialsDict["username"] {
                        if let token = credentialsDict["token"] {
                            return Credentials(
                                username,
                                password: nil,
                                token: token
                            )
                        }
                    }
                }
            } catch {
                printGit("GitHub Credentials Loading Error")
                printGit(error.localizedDescription)
            }
        }
        return nil
    }
    
    func getAuthenticationToken(_ credentials: Credentials) -> String? {
        let listArguments = [
            "-u", "\(credentials.username):\(credentials.password!)",
            "https://api.github.com/authorizations"
        ]
        
        if let list = callGitHubAPI(listArguments) {
            for item in list {
                if (item["note"] as? String) == "Atlas Token" {
                    let deleteAuthArguments = [
                        "-u", "\(credentials.username):\(credentials.password!)",
                        "-X", "DELETE",
                        "https://api.github.com/authorizations/\(item["id"]!)"
                    ]
                    _ = callGitHubAPI(deleteAuthArguments)
                }
            }
        }
        
        let authArguments = [
            "-u", "\(credentials.username):\(credentials.password!)",
            "-X", "POST",
            "https://api.github.com/authorizations",
            "-d", "{\"scopes\":[\"repo\", \"delete_repo\"], \"note\":\"Atlas Token\"}"
        ]
        
        if let authentication = callGitHubAPI(authArguments) {
            guard authentication[0]["token"] != nil else {
                printGit("Failed GitHub Authentication: \(authentication)")
                return nil
            }
            
            return authentication[0]["token"] as? String
        }
        return nil
    }
    
    func callGitHubAPI(_ arguments: [String]) -> [[String: Any]]? {
        let response = Glue.runProcess("curl", arguments: arguments)
        
        guard response.count > 0 else {
            return nil
        }
        
        let data = response.data(using: .utf8)!
        
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            
            if let singleItem = json as? [String: Any] {
                return [singleItem]
            } else if let multipleItems = json as? [[String: Any]] {
                return multipleItems
            }
            printGit("JSON response from GITHUB evaluates to nil for \(arguments): \(response)")
        } catch {
            printGit("Error deserializing JSON for \(arguments) -> \(response): \(error)")
        }
        return nil
    }
    
    func buildArguments(_ command: String, additionalArguments:[String]=[]) -> [String] {
        let path = directory.path
        return ["--git-dir=\(path)/.git", command] + additionalArguments
    }
    
    func run(_ command: String, arguments: [String]=[]) -> String {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        
        return Glue.runProcess("git",
                               arguments: fullArguments,
                               currentDirectory: directory,
                               atlasProcess: atlasProcessFactory.build()
        )
    }
    
    public func runInit() -> String {
        return run("init")
    }
    
    public func status() -> String? {
        let result = run("status")
        if (result == "") {
            return nil
        }
        return result
    }
    
    public func initGitHub() -> [String: Any]? {
        let repoArguments = [
            "-u", "\(credentials.username):\(credentials.token!)",
            "https://api.github.com/repos/\(credentials.username)/\(repositoryName)"
        ]
        
        var repoResult = callGitHubAPI(repoArguments)
        
        var repoPath = repoResult?[0]["clone_url"] as? String
        
        if repoPath == nil {
            let createRepoArguments = [
                "-u", "\(credentials.username):\(credentials.token!)",
                "https://api.github.com/user/repos",
                "-d", "{\"name\":\"\(repositoryName)\"}"
            ]
            
            repoResult = callGitHubAPI(createRepoArguments)
            
            repoPath = repoResult?[0]["clone_url"] as? String
        }
        
        guard repoPath != nil else {
            return nil
        }
        
        let authenticatedPath = repoPath!.replacingOccurrences(
            of: "https://",
            with: "https://\(credentials.username):\(credentials.token!)@"
        )
        _ = run("remote", arguments: ["add", "origin", authenticatedPath])
        
        //        setGitHubRepositoryLink()
        //
        initGitIgnore()
        
        _ = add()
        _ = commit()
        pushToGitHub()
        
        return repoResult![0]
    }
    
    func initGitIgnore() {
        do {
            let filename = directory.appendingPathComponent(".gitignore")
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filename.path) {
                do {
                    try fileManager.removeItem(at: filename)
                } catch {
                    printGit("Failed to delete .gitignore: \(error)")
                }
            }
            
            try Git.gitIgnore.joined(separator: "\n").write(to: filename, atomically: true, encoding: .utf8)
        } catch {
            printGit("Failed to save .gitignore: \(error)")
        }
    }
    
    public func removeGitHub() {
        let deleteArguments = [
            "-u", "\(credentials.username):\(credentials.token!)",
            "-X", "DELETE",
            "https://api.github.com/repos/\(credentials.username)/\(repositoryName)"
        ]
        
        _ = callGitHubAPI(deleteArguments)
    }
    
    public func add(_ filter: String=".") -> Bool {
        _ = run("add", arguments: ["."])
        
        return true
    }
    
    public func commit(_ message: String?=nil) -> String {
        return run("commit", arguments: ["-am", message ?? "Atlas commit"])
    }
    
    public func pushToGitHub() {
        _ = run("push", arguments: ["--set-upstream", "origin", "master"])
    }
    
    
    
    func printGit(_ output: String) {
        Git.printGit(output)
    }
    
    class func printGit(_ output: String) {
        print("GIT: \(output)")
    }
}

