//
//  Helper.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Cocoa
import AtlasCore

class Helper {
    
    class func initializeTest() {
        
    }
    
    class func addFile(_ name: String, directory: URL, contents: String="") {
        let filePath = "\(directory.path)/\(name)"
        let url = URL(fileURLWithPath: filePath)
        
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return
        }
    }
    
    class func createBaseDirectory(_ url: URL) {
        deleteBaseDirectory(url)
        _ = FileSystem.createDirectory(url)
    }
    
    class func deleteBaseDirectory(_ url: URL) {
        if FileSystem.fileExists(url, isDirectory: true) {
            _ = Glue.runProcess(
                "chmod",
                arguments: ["-R", "u+w", url.path],
                currentDirectory: url.deletingLastPathComponent()
            )
            _ = FileSystem.deleteDirectory(url)
        }
    }
    
}
