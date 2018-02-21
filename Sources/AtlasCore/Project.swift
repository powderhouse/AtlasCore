//
//  Project.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/21/18.
//

import Foundation

class Project {
    
    var name: String!
    var directory: URL!
    
    let states = ["unstaged", "staged", "committed"]
    
    public init(_ name: String, baseDirectory: URL) {
        self.name = name
        
        self.directory = createFolder(name, in: baseDirectory)
        let projectReadmeMessage = """
This is your \(name) project
"""
        createReadme(projectReadmeMessage)
        
        for subfolderName in self.states {
            let subfolderURL = createFolder(subfolderName)
            let readmeMessage = """
This folder contains all of your \(subfolderName) files for the project \(self.name)
"""
            createReadme(readmeMessage, in: subfolderURL)
        }
    }
    
    public func createFolder(_ name: String, in containingDirectory: URL?=nil) -> URL? {
        var dir = containingDirectory
        if dir == nil {
            dir = self.directory
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
            dir = self.directory
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
    
    public class func exists(_ name: String, in directory: URL) -> Bool {
        let projectDirectory = directory.appendingPathComponent(name)
        return FileSystem.fileExists(projectDirectory, isDirectory: true)
    }
}
