//
//  FileSystem.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public class FileSystem {
    
    public class func fileExists(_ url: URL, isDirectory: Bool=false) -> Bool {
        let fileManager = FileManager.default
        
        var isDir : ObjCBool = (isDirectory ? true : false)
        
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDirectory && isDir.boolValue || !isDirectory && !isDir.boolValue
        } else {
            return false
        }
    }
    
    public class func createDirectory(_ url: URL) -> Result {
        if fileExists(url) {
            return Result()
        }
        
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            return Result(success: false, messages: ["Unable to create directory: \(url)"])
        }
        return Result(success: true, messages: ["\(url.lastPathComponent) directory created."])
    }
    
    public class func deleteDirectory(_ url: URL) -> Result {
        var result = Result()
        let fileManager = FileManager.default
        do {
            _ = Glue.runProcess(
                "chmod",
                arguments: ["-R", "u+w", url.path],
                currentDirectory: url.deletingLastPathComponent()
            )
            
            try fileManager.removeItem(at: url)
        } catch {
            result.success = false
            result.messages.append("Unable to delete directrory: \(url) - \(error)")
        }
        return result
    }
    
    public class func filesInDirectory(_ url: URL, excluding: [String]=[], directoriesOnly: Bool=false) -> [String] {
        let fileManager = FileManager.default
        var contents = try? fileManager.contentsOfDirectory(atPath: url.path)
        
        guard contents != nil else {
            return []
        }
        
        for exclude in excluding {
            contents = contents!.filter { $0 != exclude }
        }
        
        if directoriesOnly {
            contents = contents!.filter {
                let contentUrl = url.appendingPathComponent($0)
                return fileExists(contentUrl, isDirectory: true)
            }
        }
        
        return contents!
    }
    
    public class func copy(_ filePath: String, into directory: URL) -> Result {
        return copy([filePath], into: directory)
    }
    
    public class func copy(_ filePaths: [String], into directory: URL) -> Result {
        var result = Result()
        
        for filePath in filePaths {
            let output = Glue.runProcess("cp", arguments: [filePath, directory.path])
            if let fileName = filePath.split(separator: "/").last {
                if !FileSystem.fileExists(directory.appendingPathComponent("\(fileName)")) {
                    result.success = false
                    result.messages += ["Unable to copy \(filePath) to \(directory.path)", output]
                    return result
                }
                if !FileSystem.fileExists(URL(fileURLWithPath: filePath)) {
                    result.success = false
                    result.messages += ["\(filePath) no longer exists at \(directory.path)", output]
                    return result
                }
            } else {
                result.success = false
                result.messages.append("Unable to process filename from \(filePath)")
                return result
            }
        }
        
        return result
    }

    public class func move(_ filePath: String, into directory: URL, renamedTo newName: String?=nil) -> Result {
        return move([filePath], into: directory, renamedTo: newName)
    }
    
    public class func move(_ filePaths: [String], into directory: URL, renamedTo newName: String?=nil) -> Result {
        var result = Result()
        for filePath in filePaths {
            if let fileName = filePath.split(separator: "/").last {
                let destinationName = newName == nil ? String(fileName) : newName!
                let destination = directory.appendingPathComponent(destinationName)

                let output = Glue.runProcess("mv", arguments: [filePath, destination.path])

                if !FileSystem.fileExists(destination) {
                    result.success = false
                    result.messages += ["Unable to move \(filePath)", output]
                    return result
                }
                
                if FileSystem.fileExists(URL(fileURLWithPath: filePath)) {
                    result.success = false
                    result.messages += ["\(filePath) still exists (was not moved).", output]
                    return result
                }
            } else {
                result.success = false
                result.messages.append("Unable to process filename from \(filePath)")
                return result
            }
        }
        
        return result
    }

}
