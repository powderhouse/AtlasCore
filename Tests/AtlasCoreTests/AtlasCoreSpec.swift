//
//  AtlasCoreSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/6/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class AtlasCoreSpec: QuickSpec {
    override func spec() {
        
        describe("AtlasCore") {

            var atlasCore: AtlasCore!
            
            var directory: URL!
            let credentials = Credentials(
                "atlastest",
                password: "1a2b3c4d",
                token: nil
            )
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ATLAS_CORE")
                
                FileSystem.createDirectory(directory)
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")

                atlasCore = AtlasCore(directory)
            }
            
            afterEach {
                atlasCore.deleteGitHubRepository()
                FileSystem.deleteDirectory(directory)
            }


            context("getDefaultBaseDirectory") {
                it("should provide the Application Support folder") {
                    let path = atlasCore.getDefaultBaseDirectory().path
                    expect(path).to(contain("Application Support"))
                }
            }
            
            context("with git and GitHub initialized") {
                beforeEach {
                    _ = atlasCore.initGitAndGitHub(credentials)
                }
                
                it("saves the credentials to the filesystem") {
                    if let credentialsFile = atlasCore.baseDirectory?.appendingPathComponent("credentials.json") {
                        let exists = fileManager.fileExists(atPath: credentialsFile.path, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No credentials.json found")
                    } else {
                        expect(false).to(beTrue(), description: "User directory was not set")
                    }
                    
                }

                it("saves a readme to the filesystem") {
                    if let readmeFile = atlasCore.atlasDirectory?.appendingPathComponent("readme.md") {
                        let exists = fileManager.fileExists(atPath: readmeFile.path, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No readme.md found")
                    } else {
                        expect(false).to(beTrue(), description: "Atlas directory was not set")
                    }
                }

                context("future instances of AtlasCore") {
                    var atlasCore2: AtlasCore!

                    beforeEach {
                        atlasCore2 = AtlasCore(directory)
                    }

                    it("automatically inits git") {
                        expect(atlasCore2.gitHubRepository()).to(equal("https://github.com/atlastest/Atlas"))
                    }

                    context("initialized again") {
                        var result: Bool!
                        let newCredentials = Credentials(
                            "atlastest",
                            password: "1a2b3c4d",
                            token: nil
                        )
                        
                        beforeEach {
                            result = atlasCore.initGitAndGitHub(newCredentials)
                        }

                        it("allows you to initialize again") {
                            expect(result).to(beTrue())
                        }

                        it("sets the github repository link properly") {
                            expect(atlasCore2.gitHubRepository()).to(equal("https://github.com/atlastest/Atlas"))
                        }
                    }

                }

                context("startProject") {
                    let projectName = "New Project"
                    
                    beforeEach {
                        _ = atlasCore.initProject(projectName)
                    }
                    
                    it("should create a folder in the Atlas directory with a readme") {
                        if let projectFolder = atlasCore.atlasDirectory?.appendingPathComponent(projectName) {
                            let exists = fileManager.fileExists(atPath: projectFolder.path, isDirectory: &isDirectory)
                            expect(exists).to(beTrue(), description: "No project folder found for \(projectName)")
                        } else {
                            expect(false).to(beTrue(), description: "Atlas directory was not set")
                        }
                    }

                    it("should create three subfolders, each with a readme, in the project folder") {
                        if let projectFolder = atlasCore.atlasDirectory?.appendingPathComponent(projectName) {
                            for folderName in ["unstaged", "staged", "committed"] {
                                let subfolderURL = projectFolder.appendingPathComponent(folderName)
                                let exists = fileManager.fileExists(atPath: subfolderURL.path, isDirectory: &isDirectory)
                                expect(exists).to(beTrue(), description: "No project subfolder found: \(folderName)")
                                
                                let readmePath = subfolderURL.appendingPathComponent("readme.md").path
                                let readmeExists = fileManager.fileExists(atPath: readmePath, isDirectory: &isFile)
                                expect(readmeExists).to(beTrue(), description: "No readme found in subfolder: \(folderName)")
                            }
                        } else {
                            expect(false).to(beTrue(), description: "Atlas directory was not set")
                        }
                        
                    }
                }
                
                context("log") {
                    
                    let project1Name = "General"
                    let project2Name = "AnotherProject"
                    var project1: Project!
                    var project2: Project!
                    
                    let file1 = "index1.html"
                    let file2 = "index2.html"
                    let file3 = "index3.html"
                    var fileDirectory: URL!
                    
                    let message1 = "The first commit"
                    let message2 = "The second commit"
                    
                    beforeEach {
                        fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                        FileSystem.createDirectory(fileDirectory)
                        Helper.addFile(file1, directory: fileDirectory)
                        Helper.addFile(file2, directory: fileDirectory)
                        Helper.addFile(file3, directory: fileDirectory)

                        expect(atlasCore.initProject(project2Name)).to(beTrue())
                        
                        project1 = atlasCore.project(project1Name)
                        project2 = atlasCore.project(project2Name)

                        let filePath1 = fileDirectory.appendingPathComponent(file1).path
                        expect(project1?.copyInto([filePath1])).to(beTrue())
                        atlasCore.atlasCommit()

                        expect(project1?.commitMessage(message1)).to(beTrue())
                        expect(project1?.commitStaged()).to(beTrue())
                        atlasCore.commitChanges(message1)

                        let filePath2 = fileDirectory.appendingPathComponent(file2).path
                        expect(project2?.copyInto([filePath2])).to(beTrue())

                        let filePath3 = fileDirectory.appendingPathComponent(file3).path
                        expect(project2?.copyInto([filePath3])).to(beTrue())

                        expect(project2?.commitMessage(message2)).to(beTrue())
                        expect(project2?.commitStaged()).to(beTrue())
                        atlasCore.commitChanges(message2)
                    }

                    it("should return an array of commit information ordered by date submitted") {
                        let log = atlasCore.log()
 
                        expect(log.count).to(equal(2))
                        
                        if let lastCommit = log.last {
                            expect(lastCommit.message).to(equal(message2))
                            expect(lastCommit.files.count).to(equal(2))
                            if let firstFile = lastCommit.files.first {
                                expect(firstFile.name).to(equal(file2))
                                expect(firstFile.url).to(equal("https://raw.githubusercontent.com/\(credentials.username)/Atlas/master/\(project2Name)/committed/\(project2!.commitSlug(message2))/\(file2)"))
                            }
                        }
                    }
                    
                    it("should only return the commits for a project if specified") {
                        let log = atlasCore.log("General")
                        
                        expect(log.count).to(equal(1))

                        if let lastCommit = log.last {
                            expect(lastCommit.message).to(equal(message1))
                            expect(lastCommit.files.count).to(equal(1))
                            if let firstFile = lastCommit.files.first {
                                expect(firstFile.name).to(equal(file1))
                                expect(firstFile.url).to(equal("https://raw.githubusercontent.com/\(credentials.username)/Atlas/master/\(project1Name)/committed/\(project1!.commitSlug(message1))/\(file1)"))
                            }
                        }
                    }
                }
                
                context("purge") {
                    
                    var project: Project!
                    let fileName = "index.html"
                    let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                    var commitFolder: URL!
                    var committedFilePath: String!
                    
                    beforeEach {
                        project = atlasCore.project("General")
                        let stagedDirectory = project.directory("staged")
                        Helper.addFile(fileName, directory: stagedDirectory)
                        
                        expect(project.commitMessage(commitMessage)).to(beTrue())
                        expect(project.commitStaged()).to(beTrue())
                        
                        let slug = project.commitSlug(commitMessage)
                        commitFolder = project.directory("committed").appendingPathComponent(slug)
                        
                        committedFilePath = commitFolder.appendingPathComponent(fileName).path
                        expect(atlasCore.purge([committedFilePath])).to(beTrue())
                    }
                    
                    it("removes the files from the commit folder") {
                        let committedFilePath = commitFolder.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: committedFilePath, isDirectory: &isFile)
                        expect(exists).to(beFalse(), description: "File still found in commited directory")
                    }
                    
                    it("removes the commit from the projects' log") {
                        let log = atlasCore.log()
                        expect(log.count).to(equal(0))
                    }
                }
                
                context("purge (removing two file with more than two files)") {
                    
                    var project: Project!
                    let fileName1 = "index1.html"
                    let fileName2 = "index2.html"
                    let fileName3 = "index3.html"
                    let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                    var commitFolder: URL!
                    var committedFilePath1: String!
                    var committedFilePath2: String!
                    var committedFilePath3: String!
                    
                    beforeEach {
                        project = atlasCore.project("General")
                        let stagedDirectory = project.directory("staged")
                        Helper.addFile(fileName1, directory: stagedDirectory)
                        Helper.addFile(fileName2, directory: stagedDirectory)
                        Helper.addFile(fileName3, directory: stagedDirectory)
                        
                        expect(project.commitMessage(commitMessage)).to(beTrue())
                        expect(project.commitStaged()).to(beTrue())
                        
                        let slug = project.commitSlug(commitMessage)
                        commitFolder = project.directory("committed").appendingPathComponent(slug)
                        
                        committedFilePath1 = commitFolder.appendingPathComponent(fileName1).path
                        committedFilePath2 = commitFolder.appendingPathComponent(fileName2).path
                        committedFilePath3 = commitFolder.appendingPathComponent(fileName3).path
                        expect(atlasCore.purge([committedFilePath1, committedFilePath2])).to(beTrue())
                    }
                    
                    it("removes the files from the commit folder") {
                        let exists1 = fileManager.fileExists(atPath: committedFilePath1, isDirectory: &isFile)
                        expect(exists1).to(beFalse(), description: "File 1 still found in commited directory")
                        
                        let exists2 = fileManager.fileExists(atPath: committedFilePath2, isDirectory: &isFile)
                        expect(exists2).to(beFalse(), description: "File 2 still found in commited directory")
                        
                        let exists3 = fileManager.fileExists(atPath: committedFilePath3, isDirectory: &isFile)
                        expect(exists3).to(beTrue(), description: "File 3 not found in commited directory")
                    }
                    
                    it("removes the file from the list in the commit's log") {
                        let log = atlasCore.log()
                        expect(log.count).to(equal(1))
                        
                        expect(log.first.files.count).to(equal(1))
                        expect(log.first.files.first.name).to(equal(fileName3))
                    }
                }
                
            }
        }
    }
}

