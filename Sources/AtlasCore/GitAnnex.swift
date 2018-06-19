//
//  GitAnnex.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 6/18/18.
//

import Foundation

public class GitAnnex {
    
    public let directory: URL!
    
    public init(_ directory: URL) {
        self.directory = directory
        
        if !installed() {
            _ = install()
        }
        
        _ = initDirectory()
    }
    
    public func installed() -> Bool {
        let info = Glue.runProcess("brew", arguments: ["info", "git-annex"])
        return !info.contains("Not installed")
    }
    
    public func install() -> Bool {
        let result = Glue.runProcess("brew", arguments: ["install", "git-annex"])
        return result.contains("start git-annex")
    }
    
    func buildArguments(_ command: String, additionalArguments:[String]=[]) -> [String] {
        return [command] + additionalArguments
    }
    
    func run(_ command: String, arguments: [String]=[]) -> String {
        let fullArguments = buildArguments(
            command,
            additionalArguments: arguments
        )
        
        return Glue.runProcess("git",
                               arguments: ["annex"] + fullArguments,
                               currentDirectory: directory
        )
    }
    
    public func initDirectory() -> Bool {
        let result = run("init")
        return result.contains("ok")
    }

    public func add(_ filter: String=".") -> Bool {
        let result = run("add", arguments: [filter])
        return result.contains("added")
    }
    
    public func info() -> String {
        return run("info")
    }

    
    
}
