//
//  FileSystem.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class FileSystem {
    
    public class func fileExists(_ url: URL, isDirectory: Bool=true) -> Bool {
        let fileManager = FileManager.default
        
        var isDir : ObjCBool = (isDirectory ? true : false)
        
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
    }
    
    public class func createDirectory(_ url: URL) {
        if fileExists(url) {
            return
        }
        
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Unable to create directory: \(url)")
        }
    }
    
    public class func deleteDirectory(_ url: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: url)
        } catch {}
    }
    
    public class func filesInDirectory(_ url: URL, excluding: [String]=[]) -> [String] {
        let fileManager = FileManager.default
        var contents = try? fileManager.contentsOfDirectory(atPath: url.path)
        
        guard contents != nil else {
            return []
        }
        
        for exclude in excluding {
            contents = contents!.filter { $0 != exclude }
        }
        
        return contents!
    }
    
    public class func copy(_ file: String, into directory: URL) -> Bool {
        return copy([file], into: directory)
    }
    
    public class func copy(_ files: [String], into directory: URL) -> Bool {
        for file in files {
            _ = Glue.runProcess("cp", arguments: [file, directory.path])
            if let fileName = file.split(separator: "/").last {
                if !FileSystem.fileExists(directory.appendingPathComponent("\(fileName)")) {
                    return false
                }
                if !FileSystem.fileExists(URL(fileURLWithPath: file)) {
                    return false
                }
            } else {
                return false
            }
        }
        
        return true
    }

    public class func move(_ file: String, into directory: URL) -> Bool {
        return move([file], into: directory)
    }
    
    public class func move(_ files: [String], into directory: URL) -> Bool {
        for file in files {
            _ = Glue.runProcess("mv", arguments: [file, directory.path])
            if let fileName = file.split(separator: "/").last {
                if !FileSystem.fileExists(directory.appendingPathComponent("\(fileName)")) {
                    return false
                }
                if FileSystem.fileExists(URL(fileURLWithPath: file)) {
                    return false
                }
            } else {
                return false
            }
        }
        
        return true
    }

}
