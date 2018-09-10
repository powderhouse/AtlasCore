//
//  Glue.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class Glue {
    
    public static let path: String = "$PATH:/bin:/usr/bin:/usr/local/bin:/anaconda/bin"
    
    class func gitDir() -> String? {
        return Bundle(for: AtlasCore.self).resourcePath?.appending("/git")
    }
    
    class func addEnvVars(to existing: [String: String]?) -> [String: String] {
        var env = existing ?? [:]
        
        env["HOME"] = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
            )[0]
        
        env["TMPDIR"] = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
            )[0]
        
        if let gitDir = gitDir() {
            env["GIT_EXEC_PATH"] = "\(gitDir)/libexec/git-core/"
            env["PATH"] = "\(gitDir)/bin/:\(gitDir)/libexec/git-core/:\(path)"
        } else {
            env["PATH"] = path
        }
        
        env["GIT_CONFIG_NOSYSTEM"] = "1"
        
        return env
    }
    
    public class func runProcess(_ command: String, arguments: [String]?=[], environment_variables: [String: String]?=nil, currentDirectory: URL?=nil, atlasProcess: AtlasProcess=Process()) -> String {
        let process = initializeProcess(command, arguments: arguments, environment_variables: environment_variables, currentDirectory: currentDirectory, atlasProcess: atlasProcess)
        
        return process.runAndWait()
    }
    
    public class func runProcessError(_ command: String, arguments: [String]?=[], environment_variables: [String: String]?=nil, currentDirectory: URL?=nil, atlasProcess: AtlasProcess=Process()) -> String {
        let process = initializeProcess(command, arguments: arguments, environment_variables: environment_variables, currentDirectory: currentDirectory, atlasProcess: atlasProcess)
        
        return process.runAndWaitError()
    }
    
    public class func runProcessErrorAndLog(_ command: String, arguments: [String]?=[], environment_variables: [String: String]?=nil, currentDirectory: URL?=nil, atlasProcess: AtlasProcess=Process(), log: @escaping (_ fileHandle: FileHandle) -> Void) {
        let process = initializeProcess(command, arguments: arguments, environment_variables: environment_variables, currentDirectory: currentDirectory, atlasProcess: atlasProcess)
        
        return process.runAndWaitErrorAndLog(log)
    }
    
    class func initializeProcess(_ command: String, arguments: [String]?, environment_variables: [String: String]?, currentDirectory: URL?, atlasProcess: AtlasProcess) -> AtlasProcess {
        var process = atlasProcess
        
        process.launchPath = "/usr/bin/env"
        //        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + (arguments ?? [])
        
        if currentDirectory != nil {
            process.currentDirectoryPath = currentDirectory!.path
        }
        
        process.environment = addEnvVars(to: environment_variables)
        return process
    }
    
}
