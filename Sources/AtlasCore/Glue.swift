//
//  Glue.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class Glue {
    
    public class func runProcess(_ command: String, arguments: [String]?=[], environment_variables: [String: String]?=nil, currentDirectory: URL?=nil, atlasProcess: AtlasProcess=Process()) -> String {
        var process = atlasProcess
        
        process.launchPath = "/usr/bin/env"
//        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + (arguments ?? [])
        
        if environment_variables != nil {
            process.environment = environment_variables
        }
        
        if currentDirectory != nil {
//            process.currentDirectoryURL = currentDirectory
            process.currentDirectoryPath = currentDirectory!.path
        }
        
        return process.runAndWait()
    }
    
    public class func runProcessError(_ command: String, arguments: [String]?=[], environment_variables: [String: String]?=nil, currentDirectory: URL?=nil, atlasProcess: AtlasProcess=Process()) -> String {
        var process = atlasProcess
        
        process.launchPath = "/usr/bin/env"
        //        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + (arguments ?? [])
        
        if currentDirectory != nil {
            //            process.currentDirectoryURL = currentDirectory
            process.currentDirectoryPath = currentDirectory!.path
        }
        
        if environment_variables != nil {
            process.environment = environment_variables
        }
        
        return process.runAndWaitError()
    }
    
}
