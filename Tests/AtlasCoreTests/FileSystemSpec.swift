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

class FileSystemSpec: CoreSpec {
    override func spec() {
        
        describe("FileSystem") {
            
            let fileManager = FileManager.default
            var isDir : ObjCBool = true
            var isFile : ObjCBool = false

            context("createDirectory") {
                let name = "NEWDIRECTORY"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
                let path = url.path

                it("creates a new directory at the specified path") {
                    do {
                        try fileManager.removeItem(at: url)
                    } catch {}
                    
                    let alreadyExists = fileManager.fileExists(
                        atPath: path,
                        isDirectory: &isDir
                    )
                    expect(alreadyExists).to(beFalse())
                    
                    _ = FileSystem.createDirectory(url)
                    
                    let exists = fileManager.fileExists(
                        atPath: path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beTrue())
                }
                
                it("doesn't fail if a directory already exists") {
                    _ = FileSystem.createDirectory(url)
                    
                    let exists = fileManager.fileExists(
                        atPath: path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beTrue())
                    
                    _ = FileSystem.createDirectory(url)
                }
            }
            
            context("deleteDirectory") {
                
                let deletingDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DELETING")
                var isDir : ObjCBool = true
                
                beforeEach {
                    _ = FileSystem.createDirectory(deletingDirectory)
                    let exists = fileManager.fileExists(
                        atPath: deletingDirectory.path,
                        isDirectory: &isDir
                    )
                    expect(exists).to(beTrue())
                    
                    _ = FileSystem.deleteDirectory(deletingDirectory)
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
                    _ = FileSystem.createDirectory(url)
                    for file in files {
                        let filePath = "\(url.path)/\(file)"
                        _ = Glue.runProcess("touch", arguments: [filePath])
                    }
                }
                
                it("returns a list of filenames in a directory") {
                    expect(FileSystem.filesInDirectory(url).sorted()).to(equal(files))
                }
                
                it("excludes a file if specified") {
                    let files = FileSystem.filesInDirectory(url, excluding: ["index2.html"])
                    expect(files).toNot(contain("index2.html"))
                    expect(files).to(contain("index1.html"))
                }
            }
            
            context("copy") {
                let fileName1 = "index 1.html"
                let fileName2 = "index2.html"
                var startDirectory: URL!
                var endDirectory: URL!
                
                beforeEach {
                    startDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("START")
                    endDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("END")
                    _ = FileSystem.createDirectory(startDirectory)
                    _ = FileSystem.createDirectory(endDirectory)
                    Helper.addFile(fileName1, directory: startDirectory)
                    Helper.addFile(fileName2, directory: startDirectory)
                    
                    let filePath1 = startDirectory.appendingPathComponent(fileName1).path
                    let filePath2 = startDirectory.appendingPathComponent(fileName2).path
                    expect(FileSystem.copy([filePath1, filePath2], into: endDirectory).success).to(beTrue())
                }
                
                afterEach {
                    _ = FileSystem.deleteDirectory(startDirectory)
                    _ = FileSystem.deleteDirectory(endDirectory)
                }
                
                it("adds both files to the end directory") {
                    for fileName in [fileName1, fileName2] {
                        let endFilePath = endDirectory.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: endFilePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "File not found in end directory")
                    }
                }
                
                it("leaves both files in the start directory") {
                    for fileName in [fileName1, fileName2] {
                        let startFilePath = startDirectory.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: startFilePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "File not found in start directory")
                    }
                }
                
                context("safe copy") {
                    it("replaces all spaces in the filename with underscores") {
                        let filePath1 = startDirectory.appendingPathComponent(fileName1).path
                        let filePath2 = startDirectory.appendingPathComponent(fileName2).path

                        expect(FileSystem.copy([filePath1, filePath2], into: endDirectory, safe: true).success).to(beTrue())

                        for fileName in [fileName1, fileName2] {
                            let safeFilename = fileName.replacingOccurrences(of: " ", with: "_")
                            let filePath = endDirectory.appendingPathComponent(safeFilename).path
                            let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "Safe file not found")
                        }
                    }
                }
            }
            
            context("move") {
                let fileName1 = "index1.html"
                let fileName2 = "index2.html"
                var startDirectory: URL!
                var endDirectory: URL!
                
                beforeEach {
                    startDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("START")
                    endDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("END")
                    _ = FileSystem.createDirectory(startDirectory)
                    _ = FileSystem.createDirectory(endDirectory)
                    Helper.addFile(fileName1, directory: startDirectory)
                    Helper.addFile(fileName2, directory: startDirectory)

                    for fileName in [fileName1, fileName2] {
                        let startFilePath = startDirectory.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: startFilePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "File not found in start directory")
                    }

                    let filePath1 = startDirectory.appendingPathComponent(fileName1).path
                    let filePath2 = startDirectory.appendingPathComponent(fileName2).path
                    expect(FileSystem.move([filePath1, filePath2], into: endDirectory).success).to(beTrue())
                }
                
                afterEach {
                    _ = FileSystem.deleteDirectory(startDirectory)
                    _ = FileSystem.deleteDirectory(endDirectory)
                }
                
                it("adds both files to the end directory") {
                    for fileName in [fileName1, fileName2] {
                        let endFilePath = endDirectory.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: endFilePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "File not found in end directory")
                    }
                }
                
                it("removes both files from the start directory") {
                    for fileName in [fileName1, fileName2] {
                        let startFilePath = startDirectory.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: startFilePath, isDirectory: &isFile)
                        expect(exists).to(beFalse(), description: "File still found in start directory")
                    }
                }
            }

        }
    }
}

