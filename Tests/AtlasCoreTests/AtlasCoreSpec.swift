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
                
                context("copy") {
                    let projectName = "New Project"
                    let fileName = "index.html"
                    var projectDirectory: URL!
                    var fileDirectory: URL!
                    
                    beforeEach {
                        fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                        FileSystem.createDirectory(fileDirectory)
                        Helper.addFile(fileName, directory: fileDirectory)
                        
                        _ = atlasCore.initProject(projectName)
                        projectDirectory = atlasCore.atlasDirectory?.appendingPathComponent(projectName)
                        
                        let filePath = fileDirectory.appendingPathComponent(fileName).path
                        expect(atlasCore.copy([filePath], into: projectName)).to(beTrue())
                    }
                    
                    it("adds the file to the project") {
                        if let stagedDirectory = projectDirectory?.appendingPathComponent("staged") {
                            let projectFilePath = stagedDirectory.appendingPathComponent(fileName).path
                            let exists = fileManager.fileExists(atPath: projectFilePath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "File not found in project's staged directory")
                        } else {
                            expect(false).to(beTrue(), description: "Project directory is nil")
                        }
                    }
                    
                    it("leaves the file in the file's directory") {
                        let filePath = fileDirectory.appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                        expect(exists).to(beTrue(), description: "File not found in file's directory")
                    }
                }
                
                
                context("changeState") {
                    let projectName = "New Project"
                    let fileName = "newfile.html"
                    var projectDirectory: URL!
                    
                    beforeEach {
                        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                        let fileDirectory = tempDirectory.appendingPathComponent("FILE_DIR")
                        FileSystem.createDirectory(fileDirectory)
                        Helper.addFile(fileName, directory: fileDirectory)
                        
                        _ = atlasCore.initProject(projectName)
                        projectDirectory = atlasCore.atlasDirectory?.appendingPathComponent(projectName)
                        
                        let filePath = fileDirectory.appendingPathComponent(fileName).path
                        expect(atlasCore.copy([filePath], into: projectName)).to(beTrue())

                        let result = atlasCore.changeState([fileName], within: projectName, to: "unstaged")
                        expect(result).to(beTrue())
                    }
                    
                    it("adds the file to the unstaged subfolder within the project") {
                        if let unstagedDirectory = projectDirectory?.appendingPathComponent("unstaged") {
                            let unstagedFilePath = unstagedDirectory.appendingPathComponent(fileName).path
                            let exists = fileManager.fileExists(atPath: unstagedFilePath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "File not found in unstaged directory")
                        } else {
                            expect(false).to(beTrue(), description: "Project directory is nil")
                        }
                    }
                    
                    it("removes the file from the staged directory") {
                        if let stagedDirectory = projectDirectory?.appendingPathComponent("staged") {
                            let stagedFilePath = stagedDirectory.appendingPathComponent(fileName).path
                            let exists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                            expect(exists).to(beFalse(), description: "File still found in staged directory")
                        } else {
                            expect(false).to(beTrue(), description: "Project directory is nil")
                        }
                    }
                }
                
            }
        }
    }
}

