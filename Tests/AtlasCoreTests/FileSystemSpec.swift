//
//  FileSystemSpec.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class FileSystemSpec: QuickSpec {
    override func spec() {
        
        describe("FileSystem") {
            
            let fileManager = FileManager.default
            
            context("createDirectory") {
                let name = "NEWDIRECTORY"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
                let path = url.path
                
                var isDir : ObjCBool = true
                
                it("creates a new directory at the specified path") {
                    do {
                        try fileManager.removeItem(at: url)
                    } catch {}
                    
                    let alreadyExists = fileManager.fileExists(
                        atPath: path,
                        isDirectory: &isDir
                    )
                    expect(alreadyExists).to(beFalse())
                    
                    FileSystem.createDirectory(url)
                    
                    let exists = fileManager.fileExists(
                        atPath: path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beTrue())
                }
                
                it("doesn't fail if a directory already exists") {
                    FileSystem.createDirectory(url)
                    
                    let exists = fileManager.fileExists(
                        atPath: path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beTrue())
                    
                    FileSystem.createDirectory(url)
                }
            }
            
            context("deleteDirectory") {
                
                let deletingDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DELETING")
                var isDir : ObjCBool = true
                
                beforeEach {
                    FileSystem.createDirectory(deletingDirectory)
                    let exists = fileManager.fileExists(
                        atPath: deletingDirectory.path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beTrue())
                    
                    FileSystem.deleteDirectory(deletingDirectory)
                }
                
                it("should remove the directory from the filesystem") {
                    let exists = fileManager.fileExists(
                        atPath: deletingDirectory.path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beFalse())
                }
                
            }
            
            context("filesInDirectory") {
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILEFOLDER")
                let files = ["index1.html", "index2.html", "index3.html"]
                
                beforeEach {
                    FileSystem.createDirectory(url)
                    for file in files {
                        let filePath = "\(url.path)/\(file)"
                        _ = Glue.runProcess("touch", arguments: [filePath])
                    }
                }
                
                it("returns a list of filenames in a directory") {
                    expect(FileSystem.filesInDirectory(url).sorted()).to(equal(files))
                }
            }
        }
    }
}

