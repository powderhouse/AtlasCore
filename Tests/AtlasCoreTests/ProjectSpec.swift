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
            
            var baseDirectory: URL!
            
            let projectName = "Project"
            var project: Project!
            var directory: URL!
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            let credentials = Credentials(
                "atlastest",
                password: "1a2b3c4d",
                token: nil
            )
            
            var search: Search!
            var git: Git!
            
            beforeEach {
                baseDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testGit")
                Helper.createBaseDirectory(baseDirectory)

                directory = baseDirectory.appendingPathComponent("Atlas")

                search = Search(baseDirectory, indexFileName: "PROJECT\(NSDate().timeIntervalSince1970)")
                git = Git(baseDirectory, credentials: credentials)

                project = Project(projectName, baseDirectory: directory, git: git, search: search)
            }
            
            afterEach {
                search.close()
                Helper.deleteBaseDirectory(baseDirectory)
            }
            
            context("initialization") {
                
                it("should create subfolders with readmes in them") {
                    for subfolderName in project.states {
                        let folder = project.directory().appendingPathComponent(subfolderName)
                        let exists = fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory)
                        expect(exists).to(beTrue(), description: "No subfolder found for \(subfolderName)")

                        let readme = folder.appendingPathComponent(Project.readme)
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
                    let commitMessageFileUrl = project.directory().appendingPathComponent(Project.commitMessageFile)
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
                let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit! 2"
                var commitFolder: URL!
                
                beforeEach {
                    let stagedDirectory = project.directory("staged")
                    Helper.addFile(fileName, directory: stagedDirectory)
                    
                    _ = git?.add()
                    _ = git?.commit("staging file")

                    let slug = project.commitSlug(commitMessage)

                    expect(project.commitMessage(commitMessage)).to(beTrue())
                    expect(project.commitStaged().success).to(beTrue())
                    
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
                    let commitMessageFileUrl = commitFolder.appendingPathComponent(Project.readme)
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
                    let exists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                    expect(exists).to(beFalse(), description: "File still found in staged directory")
                }
                
                it("will not use duplicate slugs") {
                    Helper.addFile("index2.html", directory: project.directory("staged"))
                    
                    _ = git?.add()
                    _ = git?.commit("staging file")

                    let slug = project.commitSlug(commitMessage)

                    expect(project.commitMessage(commitMessage)).to(beTrue())
                    expect(project.commitStaged().success).to(beTrue())
                    
                    expect(slug).to(contain("-2"))
                    commitFolder = project.directory("committed").appendingPathComponent(slug)

                    Helper.addFile("index3.html", directory: project.directory("staged"))
                    
                    _ = git?.add()
                    _ = git?.commit("staging file")
                    
                    let duplicateSlug = project.commitSlug(commitMessage.appending("-2"))
                    
                    expect(project.commitMessage(commitMessage)).to(beTrue())
                    expect(project.commitStaged().success).to(beTrue())
                    
                    expect(duplicateSlug).to(contain("-2-2"))
                    commitFolder = project.directory("committed").appendingPathComponent(duplicateSlug)
                }
                
                it("will make the commit message accessible via search") {
                    let searchTerms = "a commit"
                    let commitMessageFileUrl = commitFolder.appendingPathComponent("readme.md")
                    do {
                        let contents = try String(contentsOf: commitMessageFileUrl, encoding: .utf8)
                        expect(contents).to(contain(searchTerms))
                    } catch {
                        expect(false).to(beTrue(), description: "unable to find search terms in file")
                    }
                    
                    expect(search.search(searchTerms).count).toEventually(equal(1))
//                    expect(search.search("index").count).toEventually(equal(1))
                }
                
            }
            
            context("copy") {
                let fileName = "index.html"
                var fileDirectory: URL!
                
                beforeEach {
                    fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                    _ = FileSystem.createDirectory(fileDirectory)
                    Helper.addFile(fileName, directory: fileDirectory)
                    
                    let filePath = fileDirectory.appendingPathComponent(fileName).path
                    expect(project.copyInto([filePath]).success).to(beTrue())
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
                    _ = FileSystem.createDirectory(fileDirectory)
                    Helper.addFile(fileName, directory: fileDirectory)
                    
                    let filePath = fileDirectory.appendingPathComponent(fileName).path
                    expect(project.copyInto([filePath]).success).to(beTrue())
                    
                    let result = project.changeState([fileName], to: "unstaged")
                    expect(result.success).to(beTrue())
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
            
            context("allFileUrls") {
                
                let stagedName = "staged.html"
                let unstagedName = "unstaged.html"
                let commitedName = "committed.html"
                let commitMessage = "A commit"
                
                beforeEach {
                    let stagedDirectory = project.directory("staged")
                    Helper.addFile(commitedName, directory: stagedDirectory)
                    
                    _ = git?.add()
                    _ = git?.commit("staging file")
                    
                    _ = project.commitSlug(commitMessage)
                    
                    expect(project.commitMessage(commitMessage)).to(beTrue())
                    expect(project.commitStaged().success).to(beTrue())
                    
                    Helper.addFile(stagedName, directory: stagedDirectory)
                    Helper.addFile(unstagedName, directory: stagedDirectory)
                    _ = project.changeState([unstagedName], to: "unstaged")
                }
                
                it("should return all files") {
                    expect(project.allFileUrls().count).to(equal(4))
                }
                
            }
            
        }
    }
}
