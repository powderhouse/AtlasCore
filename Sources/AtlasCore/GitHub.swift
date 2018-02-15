//
//  GitHub.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/14/18.
//

import Foundation

public class GitHub {
    
    public var credentials: Credentials!
    public var git: Git!
    
    public var repositoryName: String
    public var repositoryLink: String?
    
    public init(_ credentials: Credentials, repositoryName: String, git: Git!) {
        self.credentials = credentials
        self.repositoryName = repositoryName
        self.git = git
    }
    
    class func api(_ arguments: [String]) -> [[String: Any]]? {
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
            printGitHub("JSON response from GITHUB evaluates to nil for \(arguments): \(response)")
        } catch {
            printGitHub("Error deserializing JSON for \(arguments) -> \(response): \(error)")
        }
        return nil
    }
    
    func api(_ arguments: [String]) -> [[String: Any]]? {
        return GitHub.api(arguments)
    }

    public func createRepository() -> [String: Any]? {
        guard credentials.token != nil else {
            return nil
        }
        
        let repoArguments = [
            "-u", "\(credentials.username):\(credentials.token!)",
            "https://api.github.com/repos/\(credentials.username)/\(repositoryName)"
        ]
        
        var repoResult = api(repoArguments)
        
        var repoPath = repoResult?[0]["clone_url"] as? String
        
        if repoPath == nil {
            let createRepoArguments = [
                "-u", "\(credentials.username):\(credentials.token!)",
                "https://api.github.com/user/repos",
                "-d", "{\"name\":\"\(repositoryName)\"}"
            ]
            
            repoResult = api(createRepoArguments)

            repoPath = repoResult?[0]["clone_url"] as? String
        }
        
        guard repoPath != nil else {
            return nil
        }
        
        let authenticatedPath = repoPath!.replacingOccurrences(
            of: "https://",
            with: "https://\(credentials.username):\(credentials.token!)@"
        )
        _ = git.run("remote", arguments: ["add", "origin", authenticatedPath])
        
        setRepositoryLink()
        
        return repoResult![0]
    }
    
    public func deleteRepository() {
        let deleteArguments = [
            "-u", "\(credentials.username):\(credentials.token!)",
            "-X", "DELETE",
            "https://api.github.com/repos/\(credentials.username)/\(repositoryName)"
        ]
        
        _ = api(deleteArguments)
    }
    
    public func url() -> String {
        let authenticatedUrl = git.run("ls-remote", arguments: ["--get-url"])

        guard authenticatedUrl.contains("https") else {
            return ""
        }
        
        return authenticatedUrl.replacingOccurrences(
            of: "https://\(credentials.username):\(credentials.token!)@",
            with: "https://"
        )
    }
    
    func setRepositoryLink() {
        repositoryLink = url().replacingOccurrences(of: ".git\n", with: "")
    }
    
    public class func getAuthenticationToken(_ credentials: Credentials) -> String? {
        guard credentials.password != nil else {
            return nil
        }
        
        let listArguments = [
            "-u", "\(credentials.username):\(credentials.password!)",
            "https://api.github.com/authorizations"
        ]
        
        if let list = api(listArguments) {
            for item in list {
                if (item["note"] as? String) == "Atlas Token" {
                    let deleteAuthArguments = [
                        "-u", "\(credentials.username):\(credentials.password!)",
                        "-X", "DELETE",
                        "https://api.github.com/authorizations/\(item["id"]!)"
                    ]
                    _ = api(deleteAuthArguments)
                }
            }
        }
        
        let authArguments = [
            "-u", "\(credentials.username):\(credentials.password!)",
            "-X", "POST",
            "https://api.github.com/authorizations",
            "-d", "{\"scopes\":[\"repo\", \"delete_repo\"], \"note\":\"Atlas Token\"}"
        ]
        
        if let authentication = api(authArguments) {
            guard authentication[0]["token"] != nil else {
                printGitHub("Failed GitHub Authentication: \(authentication)")
                return nil
            }
            
            return authentication[0]["token"] as? String
        }
        
        return nil
    }
    
    func printGitHub(_ output: String) {
        GitHub.printGitHub(output)
    }
    
    class func printGitHub(_ output: String) {
        print("GIT HUB: \(output)")
    }
}


