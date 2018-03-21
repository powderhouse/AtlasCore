//
//  ProjectSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/26/18.
//


import Foundation
import Quick
import Nimble
import AtlasCore

class ProjectSpec: QuickSpec {
    override func spec() {
        describe("Project") {
            
            let projectName = "Project"
            var project: Project!
            var directory: URL!
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testProject")
                project = Project(projectName, baseDirectory: directory)
            }
            
            afterEach {
                FileSystem.deleteDirectory(directory)
            }
            
            context("initialization") {
                
                it("should create subfolders with readmes in them") {
                    for subfolderName in project.states {
                        let folder = project.directory().appendingPathComponent(subfolderName)
                        let exists = fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory)
                        expect(exists).to(beTrue(), description: "No subfolder found for \(subfolderName)")

                        let readme = folder.appendingPathComponent("readme.md")
                        let readmeExists = fileManager.fileExists(atPath: readme.path, isDirectory: &isFile)
                        expect(readmeExists).to(beTrue(), description: "No readme found in \(subfolderName)")
                     
                        do {
                            let readmeContents = try String(contentsOf: readme, encoding: .utf8)
                            expect(readmeContents).to(contain("This folder contains all of your \(subfolderName) files for the project \(projectName)"))
                        } catch {
                            expect(false).to(beTrue(), description: "Unable to read contents of readme/")
                        }
                        
                    }
                }

            }
            
            context("commitSlug") {
                it("should provide a slug from the message") {
                    let slug = project.commitSlug("A commit message.")
                    expect(slug).to(equal("a-commit-message"))
                }
                
                it("should handle a long complicated message by truncating to 254 characters") {
                    let message = "A really-really-really long and complicated message! Just so bl@#~ping complicated*** What will the slug be? I'm really not too sure, but we'll see: \"Boo Yaa\"! Now let's do it again: A really-really-really long and complicated message! Just so bl@#~ping complicated*** What will the slug be? I'm really not too sure, but we'll see: \"Boo Yaa\"!"
                    let slug = project.commitSlug(message)
                    expect(slug).to(equal("a-really-really-really-long-and-complicated-message-just-so-bl-ping-complicated-what-will-the-slug-be-i-m-really-not-too-sure-but-we-ll-see-boo-yaa-now-let-s-do-it-again-a-really-really-really-long-and-complicated-message-just-so-bl-ping-complicated-what"))
                }
            }
            
            context("commitMessage") {
                let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                
                beforeEach {
                    expect(project.commitMessage(commitMessage)).to(beTrue())
                }
                
                it("should write the commit message to a commit_message.txt file in the project's directory") {
                    let commitMessageFileUrl = project.directory().appendingPathComponent("commit_message.txt")
                    let exists = fileManager.fileExists(atPath: commitMessageFileUrl.path, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "Commit message file not found in project directory")
                    
                    do {
                        let contents = try String(contentsOf: commitMessageFileUrl, encoding: .utf8)
                        expect(contents).to(equal(commitMessage))
                    } catch {
                        expect(false).to(beTrue(), description: "unable to load contents")
                    }
                }
                
            }
            
            context("commitStaged") {
                
                let fileName = "index.html"
                let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                var commitFolder: URL!
                
                beforeEach {
                    let stagedDirectory = project.directory("staged")
                    Helper.addFile(fileName, directory: stagedDirectory)
                    
                    expect(project.commitMessage(commitMessage)).to(beTrue())
                    expect(project.commitStaged()).to(beTrue())
                    
                    let slug = project.commitSlug(commitMessage)
                    commitFolder = project.directory("committed").appendingPathComponent(slug)
                }
                
                it("creates a folder using the slug of the commit message") {
                    let exists = fileManager.fileExists(atPath: commitFolder.path, isDirectory: &isDirectory)
                    expect(exists).to(beTrue(), description: "Commit folder not found")
                }
                
                it("moves all files into the new commit folder") {
                    let committedFilePath = commitFolder.appendingPathComponent(fileName).path
                    let exists = fileManager.fileExists(atPath: committedFilePath, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "File not found in commited directory")
                }
                
                it("moves the commit_message.txt file to the commit folder") {
                    let commitMessageFileUrl = commitFolder.appendingPathComponent("commit_message.txt")
                    let exists = fileManager.fileExists(atPath: commitMessageFileUrl.path, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "Commit message file not found in commited directory")
                    
                    do {
                        let contents = try String(contentsOf: commitMessageFileUrl, encoding: .utf8)
                        expect(contents).to(equal(commitMessage))
                    } catch {
                        expect(false).to(beTrue(), description: "unable to load contents")
                    }
                }
                
                it("removes the file from the staged directory") {
                    let stagedDirectory = project.directory("staged")
                    let stagedFilePath = stagedDirectory.appendingPathComponent(fileName).path
                    print("STAGED FILE PATH: \(stagedFilePath)")
                    let exists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                    expect(exists).to(beFalse(), description: "File still found in staged directory")
                }
            }
            
            context("copy") {
                let fileName = "index.html"
                var fileDirectory: URL!
                
                beforeEach {
                    fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                    FileSystem.createDirectory(fileDirectory)
                    Helper.addFile(fileName, directory: fileDirectory)
                    
                    let filePath = fileDirectory.appendingPathComponent(fileName).path
                    expect(project.copyInto([filePath])).to(beTrue())
                }
                
                it("adds the file to the project") {
                    let stagedDirectory = project.directory().appendingPathComponent("staged")
                    let projectFilePath = stagedDirectory.appendingPathComponent(fileName).path
                    let exists = fileManager.fileExists(atPath: projectFilePath, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "File not found in project's staged directory")
                }
                
                it("leaves the file in the file's directory") {
                    let filePath = fileDirectory.appendingPathComponent(fileName).path
                    let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                    expect(exists).to(beTrue(), description: "File not found in file's directory")
                }
            }
            
            
            context("changeState") {
                let fileName = "newfile.html"
                
                beforeEach {
                    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                    let fileDirectory = tempDirectory.appendingPathComponent("FILE_DIR")
                    FileSystem.createDirectory(fileDirectory)
                    Helper.addFile(fileName, directory: fileDirectory)
                    
                    let filePath = fileDirectory.appendingPathComponent(fileName).path
                    expect(project.copyInto([filePath])).to(beTrue())
                    
                    let result = project.changeState([fileName], to: "unstaged")
                    expect(result).to(beTrue())
                }
                
                it("adds the file to the unstaged subfolder within the project") {
                    let unstagedDirectory = project.directory().appendingPathComponent("unstaged")
                    let unstagedFilePath = unstagedDirectory.appendingPathComponent(fileName).path
                    let exists = fileManager.fileExists(atPath: unstagedFilePath, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "File not found in unstaged directory")
                }
                
                it("removes the file from the staged directory") {
                    let stagedDirectory = project.directory().appendingPathComponent("staged") 
                    let stagedFilePath = stagedDirectory.appendingPathComponent(fileName).path
                    let exists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                    expect(exists).to(beFalse(), description: "File still found in staged directory")
                }
            }
            
        }
    }
}
