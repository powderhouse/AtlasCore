//
//  Project.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/21/18.
//

import Foundation

public class Project {
    
    var name: String!
    var projectDirectory: URL!
    
    public let states = ["unstaged", "staged", "committed"]
    
    public init(_ name: String, baseDirectory: URL) {
        self.name = name
        self.projectDirectory = createFolder(name, in: baseDirectory)

        initFoldersAndReadmes()
    }
    
    public func initFoldersAndReadmes() {
        let projectReadmeMessage = """
This is your \(name) project
"""
        createReadme(projectReadmeMessage)
        
        for subfolderName in self.states {
            let subfolderURL = createFolder(subfolderName)
            let readmeMessage = """
This folder contains all of your \(subfolderName) files for the project \(name)
"""
            createReadme(readmeMessage, in: subfolderURL)
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

        let readme = dir!.appendingPathComponent("readme.md", isDirectory: false)
        if !FileSystem.fileExists(readme, isDirectory: false) {
            do {
                try "This is your \(name) project".write(to: readme, atomically: true, encoding: .utf8)
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
        return FileSystem.filesInDirectory(directory(state))
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
        
        return String(slug.prefix(254))
    }
    
    public class func exists(_ name: String, in directory: URL) -> Bool {
        let projectDirectory = directory.appendingPathComponent(name)
        return FileSystem.fileExists(projectDirectory, isDirectory: true)
    }
}
