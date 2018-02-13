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
    
    public class func filesInDirectory(_ url: URL) -> [String] {
        let fileManager = FileManager.default
        let contents = try? fileManager.contentsOfDirectory(atPath: url.path)
        
        return contents ?? []
    }
    
}
