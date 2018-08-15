//
//  Git.swift
//  AtlasCorePackageDescription
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class Git {
    
    var userDirectory: URL!
    public var directory: URL!
    public var atlasProcessFactory: AtlasProcessFactory!
    
    public var credentials: Credentials!
    
    public var gitAnnex: GitAnnex? = nil

    static let gitIgnore = [
        ".DS_Store",
        "credentials.json"
    ]
    
    public var annexRoot: String {
        get {
            if let annex = gitAnnex {
                return annex.s3Path
            } else {
                return ""
            }
        }
    }
    
    public init(_ userDirectory: URL, credentials: Credentials, processFactory: AtlasProcessFactory?=ProcessFactory()) {
        self.userDirectory = userDirectory
        self.directory = userDirectory.appendingPathComponent(AtlasCore.appName)
        self.credentials = credentials
        self.atlasProcessFactory = processFactory
    }
    
    public func initialize() -> Result {
        var result = Result()
        
        if !clone().success {
            let gitDirectoryResult = FileSystem.createDirectory(self.directory)
            result.mergeIn(gitDirectoryResult)
            
            let gitInitResult = runInit()
            result.mergeIn(gitInitResult)
            
            let gitIgnoreResult = writeGitIgnore()
            result.mergeIn(gitIgnoreResult)
            
            let addResult = add()
            result.mergeIn(addResult)
            
            let commitResult = commit()
            result.mergeIn(commitResult)
        }
        
        if gitAnnex == nil && credentials.complete() {
            gitAnnex = GitAnnex(directory, credentials: credentials)
            
            if let gitAnnexResult = gitAnnex?.initialize() {
                result.mergeIn(gitAnnexResult)
            }
        }
        
        return result
    }
    
    func buildArguments(_ command: String, additionalArguments:[String]=[]) -> [String] {
        let path = directory.path
        return ["--git-dir=\(path)/.git", command] + additionalArguments
    }
    
    func run(_ command: String, arguments: [String]=[], inDirectory: URL?=nil) -> String {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        
        return Glue.runProcessError("git",
                               arguments: fullArguments,
                               currentDirectory: inDirectory ?? directory,
                               atlasProcess: atlasProcessFactory.build()
        )        
    }
    
    public func runInit() -> Result {
        var result = Result()
        let output = run("init")
        if !(output.contains("Initialized empty Git repository") || output.contains("Reinitialized existing Git repository")) {
            result.success = false
            result.messages.append("Failed to initialize Git.")
        }
        return result
    }

    public func status() -> String? {
        let result = run("status")
        if (result == "") {
            return nil
        }
        return result
    }

    public func clone() -> Result {
        var result = Result()
        guard credentials != nil else {
            result.success = false
            result.messages.append("Unable to clone. No Credentials found.")
            return result
        }
        
        let path = credentials!.remotePath ??
                   "https://github.com/\(credentials!.username)/\(AtlasCore.appName).git"

        let output = run("clone",
                         arguments: [path],
                         inDirectory: userDirectory)
        
        if output.contains("fatal") || !FileSystem.fileExists(directory, isDirectory: true) {
            result.success = false
            result.messages += ["Unable to clone Atlas.", output]
        }
        return result
    }
    
    public func annexInfo() -> String {
        return gitAnnex?.info() ?? "Git Annex Not Initialized"
    }
    
    public func remote() -> String? {
        let result = run("remote", arguments: ["-v"])
        if (result == "") {
            return nil
        }
        return result
    }
    
    public func projects() -> [String] {
        let result = run("ls-tree", arguments: ["-d", "--name-only", "HEAD", "."])
        let names = result.split(separator: "\n").map { String($0) }
        let cleanNames = names.map { $0.starts(with: "\"") ? String($0.dropFirst().dropLast()) : $0 }
        return cleanNames.map { $0.unescaped }
    }
    
    public func writeGitIgnore() -> Result {
        var result = Result()
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
            result.success = false
            result.messages.append("Failed to save .gitignore: \(error)")
        }
        return result
    }
    
    public func add(_ filter: String=".") -> Result {
        
        if gitAnnex != nil {
            return gitAnnex!.add(filter)
        }
        
        let output = run("add", arguments: [filter])
        if output.contains("fatal") {
            return Result(
                success: false,
                messages: ["Unable to add files to git.", output]
            )
        }
        return Result()
    }
    
    public func move(_ filePath: String, into directory: URL, renamedTo newName: String?=nil) -> Result {
        return move([filePath], into: directory, renamedTo: newName)
    }
    
    public func move(_ filePaths: [String], into directory: URL, renamedTo newName: String?=nil) -> Result {
        var result = Result()
        for filePath in filePaths {
            if let fileName = filePath.split(separator: "/").last {
                let destinationName = newName == nil ? String(fileName) : newName!
                let destination = directory.appendingPathComponent(destinationName)
                
                let output = run("mv", arguments: [filePath, destination.path])
                
                let directoryComponents = directory.path.components(separatedBy: "/")
                let destinationComponents = destination.path.components(separatedBy: "/")
                let relativeComponents = destinationComponents[
                    directoryComponents.count..<destinationComponents.count
                ]
                
                if let currentStatus = status() {
                    if !currentStatus.contains(relativeComponents.joined(separator: "/")) {
                        result.success = false
                        result.messages += ["Git was unable to move files.", output]
                        return result
                    }
                } else {
                    result.success = false
                    result.messages += ["No status available in Git move", output]
                    return result
                }
                
                if FileSystem.fileExists(URL(fileURLWithPath: filePath)) {
                    result.success = false
                    result.messages += ["File still exists in original location after git move", output]
                    return result
                }
            } else {
                result.success = false
                result.messages += ["Unable to process filename in Git move."]
                return result
            }
        }
        
        return Result()
    }
    
    public func removeFile(_ filePath: String) -> Result {
        var result = Result()
        let history = run("log", arguments: ["--pretty=", "--name-only", "--follow", filePath])
        
        if history.count == 0 || history.contains("unknown revision or path") {
            result.success = false
            result.messages += ["\(filePath) does not exist in log.", history]
            return result
        }
        
        let files = history.components(separatedBy: "\n").filter { return $0.count > 0 }
        let escapedFiles = files.map { return "\"\($0)\"" }
        var filterBranchArguments = ["--force", "--index-filter", "git rm -rf --cached --ignore-unmatch \(escapedFiles.joined(separator: " "))"]
        filterBranchArguments.append(contentsOf: ["--prune-empty", "--tag-name-filter", "cat", "--", "--all"])

        if let gitAnnex = gitAnnex {
            result.mergeIn(gitAnnex.deleteFile(filePath))
        }
        
        _ = run("filter-branch", arguments: filterBranchArguments)
        _ = run("for-each-ref", arguments: ["--format='delete %(refname)'", "refs/original", "| git update-ref --stdin"])
        _ = run("reflog", arguments: ["expire", "--expire=now", "--all"])
        _ = run("gc", arguments: ["--prune=now"])
        _ = run("push", arguments: ["origin", "--force", "--all"])
        _ = run("push", arguments: ["origin", "--force", "--tags"])
                
//        git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch PuzzleSchool/staged/circuitous.png' --prune-empty --tag-name-filter cat -- --all && git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin && git reflog expire --expire=now --all && git gc --prune=now
//        git push origin --force --tags

        return result
    }
        
    public func commit(_ message: String?=nil) -> Result {
        var result = Result()
        let output = run("commit", arguments: ["-am", message ?? "Atlas commit"])
        if !output.contains("changed") &&
           !output.contains("nothing to commit, working tree clean") {
            result.success = false
            result.messages.append("Unable to commit")
        }
        result.messages.append(output)
        return result
    }
    
    public func log(projectName: String?=nil, full: Bool=true, commitSlugFilter: [String]?=nil) -> [[String: Any]] {
        var arguments = [
            "--pretty=format:<START COMMIT>%H<DELIMITER>%B<DELIMITER>",
            "--reverse",
            "--name-only",
            "--relative",
            "--",
            ":!.gitignore"
        ]
        
        if !full {
            arguments.append(contentsOf: [
                ":!*/unstaged/*",
                ":!*/staged/*",
                ":!*\(Project.readme)",
                ":!*\(Project.commitMessageFile)"
            ])
        }
        
        if projectName != nil {
            arguments.append(projectName!)
        }
        
        let log = run("log", arguments: arguments)

        var data: [[String:Any]] = []
        let commits = log.components(separatedBy: "<START COMMIT>").filter { $0.count > 0 }
        for commit in commits {
            let components = commit.components(separatedBy: "<DELIMITER>")
            if let hash = components.first {
                let message = components[1]
                if let fileString = components.last {
                    let files = fileString.components(separatedBy: "\n").filter { $0.count > 0 }
                    if commitSlugFilter != nil {
                        if let file = files.last {
                            let fileComponents = file.components(separatedBy: "/")
                            guard fileComponents.count > 1 else {
                                continue
                            }
                            
                            let commitSlug = fileComponents[fileComponents.count - 2]
                            guard commitSlugFilter!.contains(commitSlug) else {
                                continue
                            }
                        }
                    }
                    
                    data.append([
                        "message": message,
                        "hash": hash,
                        "files": files
                    ])
                }
            }
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

