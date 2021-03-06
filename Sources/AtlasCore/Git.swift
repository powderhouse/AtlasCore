//
//  Git.swift
//  AtlasCorePackageDescription
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public struct QueuedSync {
    public var result: Result?=nil
    public var completed: ((_ result: Result) -> Void)?=nil
}

public class Git {
    
    static let log = "log.txt"
    
    var userDirectory: URL!
    public var directory: URL!
    public var atlasProcessFactory: AtlasProcessFactory!
    
    public var credentials: Credentials!
    
    public var gitAnnex: GitAnnex? = nil
    
    public var syncing = false
    public var queuedSync: QueuedSync? = nil
    
    static let gitIgnore = [
        ".DS_Store",
        "credentials.json",
        ".git-rewrite"
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
    
    public class func configure(_ credentials: Credentials) {
        _ = Glue.runProcessError(
            "git",
            arguments: ["config", "--global", "user.name", credentials.username]
        )
        
        _ = Glue.runProcessError(
            "git",
            arguments: ["config", "--global", "user.email", credentials.email]
        )
    }
    
    public init(_ userDirectory: URL, credentials: Credentials, processFactory: AtlasProcessFactory?=ProcessFactory()) {
        self.userDirectory = userDirectory
        self.directory = userDirectory.appendingPathComponent(AtlasCore.appName)
        self.credentials = credentials
        self.atlasProcessFactory = processFactory
    }
    
    public func initialize(_ existingResult: Result?=nil) -> Result {
        var result = existingResult ?? Result()
        result.add("Initializing Git")
        
        if !clone().success {
            if !FileSystem.fileExists(self.directory) {
                result.add("Creating Git repository.")
                let gitDirectoryResult = FileSystem.createDirectory(self.directory)
                result.mergeIn(gitDirectoryResult)
            }
            
            if let status = status() {
                if status.lowercased().contains("not a git repository") {
                    result.add("Initializing Git repository")
                    let gitInitResult = runInit()
                    result.mergeIn(gitInitResult)
                }
            }
            
            result.add("Updating .gitignore")
            let gitIgnoreResult = writeGitIgnore()
            result.mergeIn(gitIgnoreResult)
            
            result.add("Committing .gitignore")
            result.mergeIn(add(AtlasCore.noCommitsPath))
            result.mergeIn(commit(path: AtlasCore.noCommitsPath))
        }
        
        if let origin = origin() {
            _ = run("remote", arguments: ["rm", "origin"], inDirectory: userDirectory)
            _ = run("remote", arguments: ["add", "origin", origin], inDirectory: userDirectory)
            _ = run("fetch", arguments: ["--all"])
        }
        
        if gitAnnex == nil && credentials.complete() {
            gitAnnex = GitAnnex(directory, credentials: credentials)
            
            if let gitAnnexResult = gitAnnex?.initialize(result) {
                if !gitAnnexResult.success {
                    gitAnnex = nil
                }
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
        
        let result = Glue.runProcessError("git",
                                          arguments: fullArguments,
                                          currentDirectory: inDirectory ?? directory,
                                          atlasProcess: atlasProcessFactory.build()
        )
        
        return result
    }
    
    public func runInit() -> Result {
        var result = Result()
        let output = run("init")
        if !(output.contains("Initialized empty Git repository") || output.contains("Reinitialized existing Git repository")) {
            result.success = false
            result.add("Failed to initialize Git.")
        }
        
        return result
    }
    
    public func origin() -> String? {
        guard credentials != nil else {
            return nil
        }
        
        var url = run("ls-remote", arguments: ["--get-url"])
        
        if url.isEmpty || url.contains("fatal") {
            return nil
        }
        
        url = url.replacingOccurrences(of: "\n", with: "")
        
        if let token = credentials.token {
            if !url.contains(substring: token) {
                return defaultOrigin()
            }
        }
        
        return url
    }
    
    public func defaultOrigin() -> String? {
        guard credentials?.username != nil && credentials?.token != nil else {
            return nil
        }
        
        return "https://\(credentials.username):\(credentials.token!)@github.com/\(credentials!.username)/\(AtlasCore.appName)"
    }
    
    public func status(_ path: String?=nil) -> String? {
        let result = run("status", arguments: ["-u", path].compactMap { $0 })
        if (result == "") {
            return nil
        }
        return result
    }
    
    public func clone() -> Result {
        var result = Result()
        guard credentials != nil && (credentials.remotePath != nil || credentials.token != nil) else {
            result.success = false
            result.add("Unable to clone. No Credentials found.")
            return result
        }
        
        let originPath = credentials!.remotePath ?? "\(defaultOrigin()!).git"
        
        let output = run("clone",
                         arguments: [originPath, AtlasCore.repositoryName],
                         inDirectory: userDirectory)
        
        if output.contains("fatal") {
            result.success = false
            if !output.contains("Repository not found") {
                result.add(["Unable to clone Atlas.", output])
            }
            return result
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
        let names = result.components(separatedBy: "\n").map { String($0) }
        let cleanNames = names.map { $0.starts(with: "\"") ? String($0.dropFirst().dropLast()) : $0 }
        return cleanNames.map { $0.unescaped }.filter { $0.count > 0 }
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
            result.add("Failed to save .gitignore: \(error)")
        }
        return result
    }
    
    public func add(_ filter: String=".") -> Result {
        
        if gitAnnex != nil {
            var annexFilter = filter
            if annexFilter.contains(":!:") {
                annexFilter = filter.replacingOccurrences(
                    of: ":!:",
                    with: "--exclude=")
            }
            return gitAnnex!.add(annexFilter)
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
    
    public func reset(_ path: String) -> Result {
        let output = run("reset", arguments: ["--", path])
        return Result(
            success: true,
            messages: [output]
        )
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
                        result.add(["Git was unable to move files.", output])
                        return result
                    }
                } else {
                    result.success = false
                    result.add(["No status available in Git move", output])
                    return result
                }
                
                if FileSystem.fileExists(URL(fileURLWithPath: filePath)) {
                    result.success = false
                    result.add(["File still exists in original location after git move", output])
                    return result
                }
            } else {
                result.success = false
                result.add(["Unable to process filename in Git move."])
                return result
            }
        }
        
        return Result()
    }
    
    public func removeFile(_ filePath: String, existingResult: Result?=nil) -> Result {
        var result = existingResult ?? Result()
        
        result.add("Removing \(filePath)")
        
        let fileUrl = directory.appendingPathComponent(filePath)
        if FileSystem.fileExists(fileUrl) {
            _ = FileSystem.deleteFile(fileUrl)
        } else if FileSystem.fileExists(fileUrl) {
            _ = FileSystem.deleteDirectory(fileUrl)
// This seems to prevent files that have been removed locally from being purged successfully.
//        } else {
//            result.success = false
//            result.add("Unable to find file")
//            return result
        }
        
        result.add("Removing local file and committing changes")
        _ = run("add", arguments: ["-u", filePath])
        _ = commit(path: filePath)
        
        result.add("Checking log")
        var files = [filePath]
        let history = run("log", arguments: ["--pretty=", "--name-only", "--follow", filePath])
        if history.count > 0 && !history.contains("unknown revision or path") {
            files += history.components(separatedBy: "\n").filter { return $0.count > 0 }
        }
        
        let escapedFiles = files.map { return "\"\($0)\"" }
        var filterBranchArguments = ["--force", "--index-filter", "git rm -rf --ignore-unmatch \(escapedFiles.joined(separator: " "))"]
        filterBranchArguments.append(contentsOf: ["--prune-empty", "--tag-name-filter", "cat", "--", "--all"])
        
        result.add("Running filter-branch, this can take a while. Please be patient :)")
        result.add(run("filter-branch", arguments: filterBranchArguments))
        
        result.add("Running for-each-ref")
        result.add(run("for-each-ref", arguments: ["--format='delete %(refname)'", "refs/original", "| git update-ref --stdin"]))
        
        result.add("Running reflog")
        result.add(run("reflog", arguments: ["expire", "--expire=now", "--all"]))
        
        result.add("Running garbage collection")
        result.add(run("gc", arguments: ["--prune=now"]))
        
        result.add("Pushing changes to GitHub")
        result.add(run("push", arguments: ["origin", "--force", "--all"]))
        result.add(run("push", arguments: ["origin", "--force", "--tags"]))
        
        //        git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch PuzzleSchool/staged/circuitous.png' --prune-empty --tag-name-filter cat -- --all && git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin && git reflog expire --expire=now --all && git gc --prune=now
        //        git push origin --force --tags
        
        return result
    }
    
    public func commit(_ message: String?=nil, path: String?=nil) -> Result {
        var result = Result()
        result.add("Committing changes")
        
        _ = gitAnnex?.run("fix")
        
        let message = message ?? "Atlas commit - no message provided"
        let path = path ?? "."
        let output = run("commit", arguments: ["-m", message, path])
        if !output.contains("changed") &&
            !output.contains("nothing to commit, working tree clean") {
            result.success = false
            result.add("Unable to commit: \(output)")
        }
        result.add(output)
        return result
    }
    
    public func push() -> Result {
        var result = Result()
        result.add("Pushing changes")
        result.add(run("push", arguments: ["--set-upstream", "origin", "master"]))
        return result
    }
    
    func files(modifiedOnly: Bool=false, path: String=".") -> [String] {
        var arguments: [String] = []
        if modifiedOnly {
            arguments += ["--others", "--modified"]
        }
        arguments += ["--", path]
        
        return run("ls-files", arguments: arguments).components(separatedBy: "\n").filter { $0.count > 0 }
    }
    
    func remoteFiles() -> [String] {
        return gitAnnex?.files() ?? []
    }
    
    public func filesSyncedWithAnnex() -> Bool {
        let missing = missingFilesBetweenLocalAndS3()
        if missing["local"]!.count > 0 || missing["remote"]!.count > 0 {
            return false
        }
        return true
    }
    
    public func missingFilesBetweenLocalAndS3() -> [String: [String]] {
        let local: [String] = []
        let remote: [String] = []
        var missing = [
            "local": local,
            "remote": remote
        ]
        
        let ignore = [
            "annex-uuid"
        ]
        
        let annexFiles = remoteFiles()
        let localFiles = self.files()
        
        for gitFile in localFiles where !ignore.contains(gitFile) {
            if !annexFiles.contains(gitFile) {
                missing["remote"]!.append(gitFile)
            }
        }
        
        for annexFile in annexFiles where !ignore.contains(annexFile) {
            if !localFiles.contains(annexFile) {
                missing["local"]!.append(annexFile)
            }
        }
        return missing
    }
    
    public func sync(_ existingResult: Result?=nil, completed: ((_ result: Result) -> Void)?=nil) -> Result {
        var result = existingResult ?? Result()
        
        if syncing {
            self.queuedSync = QueuedSync(result: result, completed: completed)
            result.add("Git sync in progress. Waiting for it to complete...")
            return result
        }
        
        syncing = true
        
        let resultLog = result.log
        result.log = { message in
            if let existingLog = resultLog {
                existingLog(message)
            }
            
            _ = self.writeToLog(message)
        }
        
        let start = "<STARTENTRY>"
        let end = "</ENDENTRY>"
        let starts = syncLog()?.components(separatedBy: start).count ?? 0
        let ends = syncLog()?.components(separatedBy: end).count ?? 0
        
        if starts > ends {
            _ = writeToLog(end)
        }
        
        _ = writeToLog(start)
        result.add("Syncing with Github")
        _ = run("pull", arguments: ["origin", "master"])
        
        let output = push().allMessages
        if !(output.contains("Everything up-to-date") || output.contains("master -> master") || output.contains("set up to track remote branch")) {
            result.success = false
            result.add("Failed to push to GitHub: \(output)")
        } else if !output.contains("Create a pull request") {
            result.add(output)
        }
        
        let endEntry: (_ result: Result) -> Void = { result in
            _ = self.writeToLog(end)
            if let completed = completed {
                completed(result)
            }
            
            self.syncing = false
            if let queuedSync = self.queuedSync {
                self.queuedSync = nil
                _ = self.sync(queuedSync.result, completed: queuedSync.completed)
            }
        }
        if let gitAnnex = gitAnnex {
            if filesSyncedWithAnnex() {
                endEntry(result)
            } else {
                gitAnnex.sync(result, completed: endEntry)
            }
        } else {
            endEntry(result)
        }
        
        return result
    }
    
    func writeToLog(_ message: String) -> Result {
        var result = Result()
        let logUrl = directory.appendingPathComponent("../\(Git.log)")
        if !FileSystem.fileExists(logUrl) {
            do {
                try "".write(to: logUrl, atomically: true, encoding: .utf8)
            } catch {
                result.success = false
                result.add("Unable to initialize log at \(logUrl): \(error)")
                return result
            }
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: logUrl) {
            fileHandle.seekToEndOfFile()
            let data = message.appending("\n\n").data(using: .utf8) ?? Data()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
        return result
    }
    
    public func syncLog() -> String? {
        if let logUrl = userDirectory?.appendingPathComponent(Git.log) {
            return try? String(contentsOf: logUrl, encoding: .utf8)
        }
        return nil
    }
    
    public func log(projectName: String?=nil, full: Bool=true, commitSlugFilter: [String]?=nil) -> [[String: Any]] {
        let startCommit = "<STARTCOMMIT>"
        let delimiter = "<DELIMITER>"
        
        var arguments = [
            "--pretty=format:\(startCommit)%H\(delimiter)%ad\(delimiter)%aE\(delimiter)%B\(delimiter)",
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
                ":!*\(AtlasCore.jsonFilename)",
                ":!*\(Project.readme)",
                ":!*\(Project.commitMessageFile)"
                ])
        }
        
        if projectName != nil {
            arguments.append(projectName!)
        }
        
        let log = run("log", arguments: arguments)
        
        if log.contains("fatal: your current branch \'master\' does not have any commits yet\n") {
            return []
        }
        
        var data: [[String:Any]] = []
        let commits = log.components(separatedBy: startCommit).filter { $0.count > 0 }
        for commit in commits {
            let components = commit.components(separatedBy: delimiter)
            if let hash = components.first {
                if components.count > 1 {
                    let message = components[3]
                    
                    if message.contains("git-annex in") {
                        continue
                    }
                    
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
                            "date": components[1],
                            "author": components[2],
                            "hash": hash,
                            "files": files
                            ])
                    }
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

