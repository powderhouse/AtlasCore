//
//  Git.swift
//  AtlasCorePackageDescription
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class Git {
    
    var directory: URL!
    public var atlasProcessFactory: AtlasProcessFactory!

    static let gitIgnore = [
        "DS_Store",
        "credentials.json"
    ]
    
    public init(_ directory: URL, processFactory: AtlasProcessFactory?=ProcessFactory()) {
        self.directory = directory
        self.atlasProcessFactory = processFactory
        
        if status() == nil {
            _ = runInit()
        }
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
    
    public func writeGitIgnore() {
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
    
    public func add(_ filter: String=".") -> Bool {
        _ = run("add", arguments: ["."])
        
        return true
    }
    
    public func removeFile(_ filePath: String) -> Bool {
        _ = run("rm", arguments: [filePath])
        _ = commit()
        _ = run("filter-branch", arguments: ["--force", "--index-filter", "git rm --cached --ignore-unmatch \(filePath)", "--prune-empty", "--tag-name-filter", "cat", "--", "--all"])
        _ = run("for-each-ref", arguments: ["--format='delete %(refname)'", "refs/original", "| git update-ref --stdin"])
        _ = run("reflog", arguments: ["expire", "--expire=now", "-all"])
        _ = run("gc", arguments: ["--prune=now"])
        _ = run("push", arguments: ["origin", "master", "--force"])
//        git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch PuzzleSchool/committed/second-commit/laurensevent.jpg' --prune-empty --tag-name-filter cat -- --all && git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin && git reflog expire --expire=now --all && git gc --prune=now
//        git push origin --force --tags
        return true
    }
    
    public func commit(_ message: String?=nil) -> String {
        return run("commit", arguments: ["-am", message ?? "Atlas commit"])
    }
    
    public func pushToGitHub() {
        _ = run("push", arguments: ["--set-upstream", "origin", "master"])
    }
    
    public func log(_ projectName: String?=nil) -> [[String: Any]] {
        var arguments = [
            "--pretty=format:|%s",
            "--reverse",
            "--name-only",
            "--relative",
            "--",
            ":!*/unstaged/*",
            ":!*/staged/*",
            ":!*readme.md"
        ]
        
        if projectName != nil {
            arguments.append("\(projectName!)/committed")
        }
    
        let log = run("log", arguments: arguments)

        var data: [[String:Any]] = []
        let commits = log.split(separator: "|")
        for commit in commits {
            var info = String(commit).split(separator: "\n")
            let message = String(info.removeFirst())
            
            data.append([
                "message": message,
                "files": info.map { String($0) }.filter { !$0.contains("commit_message.txt") }
            ])
        }
        
        return data
    }
    
    func printGit(_ output: String) {
        Git.printGit(output)
    }
    
    class func printGit(_ output: String) {
        print("GIT: \(output)")
    }
}

