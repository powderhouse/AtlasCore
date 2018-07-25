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
    
    public let states = ["unstaged", "staged", "committed"]
    
    public static let commitMessageFile = "commit_message.txt"
    public static let readme = "readme.md"
    
    var search: Search?
    var git: Git!

    public init(_ name: String, baseDirectory: URL, git: Git, search: Search?=nil) {
        self.name = name
        self.projectDirectory = createFolder(name, in: baseDirectory)
        self.search = search
        self.git = git

        initFoldersAndReadmes()
    }
    
    public func initFoldersAndReadmes() {
        if let projectName = name {
            let projectReadmeMessage = """
            This is your \(projectName) project
            """
            createReadme(projectReadmeMessage)
            
            for subfolderName in self.states {
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
        if !FileSystem.fileExists(folderURL, isDirectory: true) {
            FileSystem.createDirectory(folderURL)
        }
        return folderURL
    }
    
    public func createReadme(_ message: String, in containingDirectory: URL?=nil) {
        var dir = containingDirectory
        if dir == nil {
            dir = self.projectDirectory
        }
        
        guard dir != nil else { return }

        let readme = dir!.appendingPathComponent(Project.readme, isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try message.write(to: readme, atomically: true, encoding: .utf8)
            } catch {
                return
            }
        }
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
        for state in states {
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
    
    public func commitStaged() -> Bool {
        let commitMessage = currentCommitMessage()
        
        guard commitMessage != nil else {
            return false
        }
        
        let commitedUrl = directory("committed")
        let slug = commitSlug(commitMessage!.text)
        let commitUrl = commitedUrl.appendingPathComponent(slug)
        FileSystem.createDirectory(commitUrl)
        
        if !git.move(commitMessage!.url.path, into: commitUrl, renamedTo: Project.readme) {
            if !FileSystem.move(commitMessage!.url.path, into: commitUrl, renamedTo: Project.readme) {
                return false
            }
        }
        
        let stagedFolder = directory("staged")
        let filePaths = files("staged").map { stagedFolder.appendingPathComponent($0).path }
        if !git.move(filePaths, into: commitUrl) {
            if !FileSystem.move(filePaths, into: commitUrl) {
                return false
            }
        }
                
        var statusComplete = false
        while !statusComplete {
            if let status = git.status() {
                print("STATUS: \(status)")
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
        
        for file in FileSystem.filesInDirectory(commitUrl) {
            _ = search?.add(commitUrl.appendingPathComponent(file))
        }
        
        return true
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
        return FileSystem.fileExists(projectDirectory, isDirectory: true)
    }
    
    public func changeState(_ fileNames: [String], to state: String) -> Bool {
        var filePaths: [String] = []
        for fileName in fileNames {
            let fromState = state == "staged" ? "unstaged" : "staged"
            let file = directory(fromState).appendingPathComponent(fileName)
            filePaths.append(file.path)
        }
        if !git.move(filePaths, into: directory(state)) {
            return FileSystem.move(filePaths, into: directory(state)) 
        }
        return true
    }
    
    public func copyInto(_ filePaths: [String]) -> Bool {
        return FileSystem.copy(filePaths, into: directory("staged"))
    }
}
