//
//  Glue.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class Glue {
    
    public class func runProcess(_ command: String, arguments: [String]?=[], currentDirectory: URL?=nil, atlasProcess: AtlasProcess=Process(), async:Bool=false) -> String {
        var process = atlasProcess
        
        process.launchPath = "/usr/bin/env"
//        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + (arguments ?? [])
        
        if currentDirectory != nil {
//            process.currentDirectoryURL = currentDirectory
            process.currentDirectoryPath = currentDirectory!.path
        }
        
        if async {
            process.runAsync()
            return "OK"
        }
        
        return process.runAndWait()
    }
    
}
