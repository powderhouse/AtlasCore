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
                        expect(atlasCore2.gitHubRepository()).toNot(beNil())
                    }
                    
                    it("allows you to initialize again") {
                        let result = atlasCore.initGitAndGitHub(credentials)
                        expect(result).to(beTrue())
                    }

                }

            
                context("startProject") {
                    
                    let projectName = "New Project"
                    
                    beforeEach {
                        _ = atlasCore.startProject(projectName)
                    }
                    
                    it("should create a folder in the Atlas directory") {
                        if let projectFolder = atlasCore.atlasDirectory?.appendingPathComponent(projectName) {
                            let exists = fileManager.fileExists(atPath: projectFolder.path, isDirectory: &isDirectory)
                            expect(exists).to(beTrue(), description: "No project folder found for \(projectName)")
                        } else {
                            expect(false).to(beTrue(), description: "Atlas directory was not set")
                        }
                    }
                    
                    it("commits changes") {
                        expect(atlasCore.status()).to(contain("nothing to commit"))
                    }
                }
}
            
        }
    }
}

