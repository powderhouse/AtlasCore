//
//  GitHub.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/14/18.
//

import Foundation

public class GitHub {
    
    static let log = "log.txt"
    static let syncScriptName = "atlas-sync.sh"
    static let postCommitScriptName = "post-commit"

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

    public func createRepository() -> Result {
        if credentials.token != nil {
            return createGitHubRepository()
        } else {
            return createLocalRepository()
        }
    }
    
    public func createGitHubRepository() -> Result {
        var result = Result()
        
        guard credentials.token != nil else {
            result.success = false
            result.messages.append("No token found in credentials when creating GitHub repository.")
            return result
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
            result.success = false
            result.messages.append("Repo creation for GitHub failed.")
            return result
        }
        
        let authenticatedPath = repoPath!.replacingOccurrences(
            of: "https://",
            with: "https://\(credentials.username):\(credentials.token!)@"
        )
        
        _ = git.run("remote", arguments: ["rm", "origin"])
        _ = git.run("remote", arguments: ["add", "origin", authenticatedPath])

        if validRepository() {
            return setRepositoryLink()
        } else {
            result.success = false
            result.messages.append("Valid repository not created successfully.")
        }
        return result
    }
    
    public func createLocalRepository() -> Result {
        var result = Result()
        
        guard credentials.remotePath != nil else {
            result.success = false
            result.messages.append("Remote path for local GitHub repository not found.")
            return result
        }
        
        let remoteUrl = URL(fileURLWithPath: credentials.remotePath!, isDirectory: true)
        
        result.mergeIn(FileSystem.createDirectory(remoteUrl))
        
        _ = Glue.runProcessError("git",
                        arguments: ["init", "--bare"],
                        currentDirectory: remoteUrl
        )
        
        _ = git.run("remote", arguments: ["rm", "origin"])
        _ = git.run("remote", arguments: ["add", "origin", credentials.remotePath!])
        
        if validRepository() {
            return setRepositoryLink()
        } else {
            result.success = false
            result.messages.append("Valid local repository not created successfully.")
        }
        return result
    }
    
    public func validRepository() -> Bool {
        let update = git.run("remote", arguments: ["update"])
        if update.count == 0 { return false }
        if update.contains("error: Could not fetch origin") { return false }
        return true
    }
    
    public func deleteRepository() {
        guard credentials.token != nil else {
            return
        }
        
        let deleteArguments = [
            "-u", "\(credentials.username):\(credentials.token!)",
            "-X", "DELETE",
            "https://api.github.com/repos/\(credentials.username)/\(repositoryName)"
        ]
        
        _ = api(deleteArguments)
    }
    
    public func url() -> String {
        let authenticatedUrl = git.run("ls-remote", arguments: ["--get-url"])

        if authenticatedUrl.contains("https") {
            return authenticatedUrl.replacingOccurrences(
                of: "https://\(credentials.username):\(credentials.token!)@",
                with: "https://"
            )
        } else {
            return authenticatedUrl
        }
    }
    
    public func setRepositoryLink() -> Result {
        let fullUrl = url()
        if fullUrl.isEmpty || fullUrl.contains("fatal") {
            return Result(
                success: false,
                messages: ["No repository URL found.", fullUrl]
            )
        }
        repositoryLink = url().replacingOccurrences(of: ".git\n", with: "")
        return Result()
    }
    
    public func hooks() -> URL {
        let gitURL = git.directory.appendingPathComponent(".git")
        return gitURL.appendingPathComponent("hooks")
    }
    
    public func setPostCommitHook() -> Result {
        var result = Result()
        
        let hooksURL = hooks()
        let postCommitURL = hooksURL.appendingPathComponent(GitHub.postCommitScriptName)
        let atlasScriptURL = hooksURL.appendingPathComponent(GitHub.syncScriptName)
        let logURL = git.directory.appendingPathComponent("../\(GitHub.log)")

        let script = """
#!/bin/sh

DATE=`date '+%Y-%m-%d %H:%M:%S'`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "<STARTENTRY>"
echo ""
echo "Recorded: ${DATE}"
echo ""

export AWS_ACCESS_KEY_ID=\(credentials.s3AccessKey ?? "")
export AWS_SECRET_ACCESS_KEY=\(credentials.s3SecretAccessKey ?? "")

(cd "${DIR}" && cd "../.." && git pull origin master) || true
(cd "${DIR}" && cd "../.." && git push --set-upstream origin master) || true
# (cd "${DIR}" && cd "../.." && git annex sync --content) || true

echo ""
echo "</ENDENTRY>"
"""
        let atlasScriptResult = write(script, to: atlasScriptURL)
        guard atlasScriptResult.success else {
            result.messages.append("Unable to write atlas script.")
            result.mergeIn(atlasScriptResult)
            return result
        }

        let badText = "Bad file descriptor"
        let hook = """
#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
(cd "${DIR}" && ./atlas-sync.sh) | grep -v '\(badText)' >> \(logURL.path.replacingOccurrences(of: " ", with: "\\ ")) 2>&1 &
"""
        let postCommitResult = write(hook, to: postCommitURL)
        if !postCommitResult.success {
            result.messages.append("Unable to write post commit hook")
        }
        result.mergeIn(postCommitResult)
        return result
    }
    
    public func write(_ script: String, to url: URL) -> Result {
        var result = Result()
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            result.success = false
            result.messages.append("Unable to write script to \(url): \(error)")
            return result
        }
        
        _ = Glue.runProcess(
            "chmod",
            arguments: ["777", url.path],
            currentDirectory: url.deletingLastPathComponent()
        )
        return result
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


