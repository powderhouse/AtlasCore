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
        "github.json"
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
    
    func writeGitIgnore() {
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

