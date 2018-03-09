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
    
    public func commit(_ message: String?=nil) -> String {
        return run("commit", arguments: ["-am", message ?? "Atlas commit"])
    }
    
    public func pushToGitHub() {
        _ = run("push", arguments: ["--set-upstream", "origin", "master"])
    }
    
    public func log() -> [[String: Any]] {
        let arguments = [
            "--pretty=format:|%s",
            "--reverse",
            "--name-only",
            "--",
            ".",
            ":*/committed/*"
        ]
        
        let log = run("log", arguments: arguments)
        
        print("")
        print("LOG: \(log)")
        print("")
        var data: [[String:Any]] = []
        let commits = log.split(separator: "|")
        for commit in commits {
            var info = String(commit).split(separator: "\n")
            let message = String(info.removeFirst())

            print("")
            print("INFO: \(info.count) -> \(info)")
            print("")
            print("FLATMAP: \(info.map { String($0) })")
            print("")

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

