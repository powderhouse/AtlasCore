//
//  Project.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/21/18.
//

import Foundation

public struct CommitMessage {
    public var url: URL!
    public var text: String!
}

public class Project {
    
    public var name: String!
    var projectDirectory: URL!
    
    public static let unstaged = "unstaged"
    public static let staged = "staged"
    public static let committed = "committed"
    public static let states = [unstaged, staged, committed]
    
    public static let commitMessageFile = "commit_message.txt"
    public static let readme = "readme.md"
    
    var search: Search?
    var git: Git!

    let externalLog: ((_ message: String) -> Void)?
    
    public init(_ name: String, baseDirectory: URL, git: Git, search: Search?=nil, externalLog: ((_ message: String) -> Void)?=nil) {
        self.name = name
        self.search = search
        self.git = git
        self.externalLog = externalLog
        
        self.projectDirectory = baseDirectory.appendingPathComponent(name)
        if !FileSystem.fileExists(self.projectDirectory) {
            if let externalLog = externalLog {
                externalLog("Initializing project: \(name)")
            }
            self.projectDirectory = createFolder(name, in: baseDirectory)
        }

        initFoldersAndReadmes()
    }
    
    public func initFoldersAndReadmes() {
        if let projectName = name {
            let projectReadmeMessage = """
            This is your \(projectName) project
            """
            createReadme(projectReadmeMessage)
            
            for subfolderName in Project.states {
                let subfolderURL = createFolder(subfolderName)
                let readmeMessage = """
                This folder contains all of your \(subfolderName) files for the project \(projectName)
                """
                createReadme(readmeMessage, in: subfolderURL)
            }
        }
    }
    
    public func createFolder(_ name: String, in containingDirectory: URL?=nil) -> URL? {
        var dir = containingDirectory
        if dir == nil {
            dir = self.projectDirectory
        }
        
        guard dir != nil else { return nil }
        
        let folderURL = dir!.appendingPathComponent(name)
        if !FileSystem.fileExists(folderURL) {
            _ = FileSystem.createDirectory(folderURL)
        }
        return folderURL
    }
    
    public func createFile(_ url: URL, message: String) {
        if !FileSystem.fileExists(url) {
            do {
                try message.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return
            }
        }
    }
    
    public func createReadme(_ message: String, in containingDirectory: URL?=nil) {
        var dir = containingDirectory
        if dir == nil {
            dir = self.projectDirectory
        }
        
        guard dir != nil else { return }
        createFile(dir!.appendingPathComponent(Project.readme), message: message)
    }
    
    public func directory(_ name: String?=nil) -> URL {
        guard name != nil else {
            return self.projectDirectory
        }
        
        return projectDirectory.appendingPathComponent(name!)
    }
    
    public func files(_ state: String) -> [String] {
        return FileSystem.filesInDirectory(directory(state), excluding: [Project.readme])
    }
    
    public func allFileUrls() -> [URL] {
        var all: [URL] = []
        for state in Project.states {
            if state == "committed" {
                let commits = files(state)
                for commit in commits {
                    let commitDirectory = directory(state).appendingPathComponent(commit)
                    let commitFiles = FileSystem.filesInDirectory(commitDirectory)
                    all += commitFiles.map { commitDirectory.appendingPathComponent($0) }
                }
            } else {
                all += files(state).map { directory(state).appendingPathComponent($0) }
            }
        }
        return all
    }
    
    public func commitMessage(_ message: String) -> Bool {
        let commitMessageURL = directory().appendingPathComponent(Project.commitMessageFile)
        do {
            try message.write(to: commitMessageURL, atomically: true, encoding: .utf8)
        } catch {
            return false
        }
        
        return true
    }
    
    public func currentCommitMessage() -> CommitMessage? {
        let commitMessageUrl = directory().appendingPathComponent(Project.commitMessageFile)
        if !FileSystem.fileExists(commitMessageUrl) {
            print("No commit message found.")
            return nil
        }
        
        var commitMessage: String
        do {
            commitMessage = try String(contentsOf: commitMessageUrl, encoding: .utf8)
        } catch {
            print("Unable to read commit message")
            return nil
        }
        return CommitMessage(url: commitMessageUrl, text: commitMessage)
    }
    
    public func commitStaged() -> Result {
        var result = Result(log: externalLog)
        let commitMessage = currentCommitMessage()
        
        guard commitMessage != nil else {
            result.success = false
            result.add("Unable to commit. No commit message provided.")
            return result
        }
        
        result.add("Creating commit directory")
        let commitedUrl = directory("committed")
        let slug = commitSlug(commitMessage!.text)
        let commitUrl = commitedUrl.appendingPathComponent(slug)
        let directoryResult = FileSystem.createDirectory(commitUrl)
        result.mergeIn(directoryResult)
        
        result.add("Moving files to commit directory")
        let gitMoveResult = git.move(
            commitMessage!.url.path,
            into: commitUrl,
            renamedTo: Project.readme
        )
        if !gitMoveResult.success {
            let fileSystemMoveResult = FileSystem.move(
                commitMessage!.url.path,
                into: commitUrl,
                renamedTo: Project.readme
            )
            if !fileSystemMoveResult.success {
                result.mergeIn(fileSystemMoveResult)
                return result
            }
        }
        
        let stagedFolder = directory("staged")
        let filePaths = files("staged").map { stagedFolder.appendingPathComponent($0).path }

        if !git.move(filePaths, into: commitUrl).success {
            let fileSystemMoveResult = FileSystem.move(filePaths, into: commitUrl)
            if !fileSystemMoveResult.success {
                result.mergeIn(fileSystemMoveResult)
                return result
            }
        }
        
        var statusComplete = false
        while !statusComplete {
            if let status = git.status() {
                if status.contains("fatal") {
                    result.success = false
                    result.add("Unable to commit staged files: \(status)")
                    return result
                }
                
                statusComplete = status.contains(slug)
                for filePath in filePaths {
                    let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                    if !status.contains(fileName) {
                        statusComplete = false
                    }
                }
            }
            if (!statusComplete) {
                sleep(1)
            }
        }
        
        result.add("Indexing files for search")
        for file in FileSystem.filesInDirectory(commitUrl) {
            _ = search?.add(commitUrl.appendingPathComponent(file))
        }
        
        return result
    }
    
    public func commitSlug(_ message: String) -> String {
        var slug = message.lowercased()
        
        for pattern in ["(\\s+)", "[^\\w\\-]+", "[-]+"] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSMakeRange(0, slug.count)
                slug = regex.stringByReplacingMatches(in: slug, options: [], range: range, withTemplate: "-")
            }
        }
        
        if slug.last == "-" { slug.removeLast() }
        if slug.first == "-" { slug.removeFirst() }
        
        slug = String(slug.prefix(254))
        
        var indexSlug = slug
        var slugIndex = 1
        for previousCommit in files("committed").sorted() {
            if previousCommit == indexSlug {
                slugIndex += 1
                indexSlug = slug.appending("-\(slugIndex)")
            }
        }
        
        return indexSlug
    }
    
    public class func exists(_ name: String, in directory: URL) -> Bool {
        guard !Git.gitIgnore.contains(name) else { return false }
        let projectDirectory = directory.appendingPathComponent(name)
        return FileSystem.fileExists(projectDirectory)
    }
    
    public func changeState(_ fileNames: [String], to state: String) -> Result {
        var result = Result(log: externalLog)
        var filePaths: [String] = []
        for fileName in fileNames {
            let fromState = state == "staged" ? "unstaged" : "staged"
            let file = directory(fromState).appendingPathComponent(fileName)
            filePaths.append(file.path)
        }
        
        result.add("Moving files to \(state) directory")
        if !git.move(filePaths, into: directory(state)).success {
            let fileSystemMove = FileSystem.move(filePaths, into: directory(state))
            if !fileSystemMove.success {
                result.add("Unable to change state of files.")
                result.mergeIn(fileSystemMove)
                return result
            }
        }
        return result
    }
    
    public func copyInto(_ filePaths: [String]) -> Result {
        var result = Result(log: externalLog)
        result.add("Copying files into staged directory")
        result.mergeIn(FileSystem.copy(filePaths, into: directory("staged"), safe: true))
        return result
    }
}
