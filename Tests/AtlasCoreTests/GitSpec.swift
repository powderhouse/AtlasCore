//
//  GitSpec.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class GitSpec: QuickSpec {
    override func spec() {
        describe("Git") {
            
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
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GIT")
                
                FileSystem.createDirectory(directory)
                
                let filePath = directory.path
                let fileManager = FileManager.default
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
            }
            
            afterEach {
                FileSystem.deleteDirectory(directory)
            }
            
            context("initialization") {
                
                context("with proper credentials") {
                    var git: Git!
                    
                    beforeEach {
                        git = Git(directory, credentials: credentials)
                    }
                    
                    it("is not nil") {
                        expect(git).toNot(beNil())
                    }
                    
                    it("saves the credentials to the filesystem") {
                        let filePath = "\(directory.path)/github.json"
                        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No github json found")
                    }
                }
                
                context("without proper credentials") {
                    it("fails without proper credentials") {
                        let badCredentials = Credentials("test", password: nil, token: nil)
                        let git = Git(directory, credentials: badCredentials)
                        expect(git).to(beNil())
                    }
                }
            }
            
            context("getCredentials") {
                it("returns the credentials saved to the filesystem") {
                    _ = Git(directory, credentials: credentials)
                    let returnedCredentials = Git.getCredentials(directory)
                    
                    expect(returnedCredentials).toNot(beNil())
                    expect(returnedCredentials?.username).to(equal(credentials.username))
                    expect(returnedCredentials?.token).toNot(beNil())
                    expect(returnedCredentials?.password).to(beNil())
                }
            }
            
            context("initialized instance") {
                var git: Git!
                
                beforeEach {
                    git = Git(directory, credentials: credentials)
                }
                
                context("saveCredentials") {
                    it("writes the credentials to the filesystem") {
                        git!.saveCredentials(Credentials("test", password: nil, token: nil))
                        
                        let filePath = "\(directory.path)/github.json"
                        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No github json found")
                    }
                }
                
                context("status" ){
                    it("should be nil if not yet git initialized") {
                        expect(git!.status()).to(beNil())
                    }
                }
                
                context("runInit") {
                    it("should init as seen in a new status") {
                        expect(git!.status()).to(beNil())
                        _ = git!.runInit()
                        
                        let status = git!.status()
                        expect(status).to(contain("On branch master"))
                        expect(status).to(contain("Untracked files"))
                        expect(status).to(contain("github.json"))
                    }
                    
                    context("git initialized") {
                        beforeEach {
                            _ = git!.runInit()
                        }
                        
                        context("status") {
                            it("should no longer be nil") {
                                expect(git!.status()).toNot(beNil())
                            }
                        }
                        
                        context("add") {
                            it("should do nothing when nothing is avalable to add") {
                                do {
                                    try fileManager.removeItem(atPath: "\(directory.path)/github.json")
                                } catch {}
                                
                                let preStatus = git!.status()
                                expect(preStatus).to(contain("nothing to commit"))
                                expect(preStatus).toNot(contain("Changes to be committed"))
                                
                                expect(git!.add()).toNot(beNil())
                                
                                let postStatus = git!.status()
                                expect(postStatus).to(contain("nothing to commit"))
                                expect(postStatus).toNot(contain("Changes to be committed"))
                            }
                            
                            it("should add a file") {
                                Helper.addFile("index.html", directory: directory)
                                
                                let preStatus = git!.status()
                                expect(preStatus).to(contain("index.html"))
                                expect(preStatus).to(contain("nothing added to commit"))
                                
                                expect(preStatus).toNot(contain("Changes to be committed"))
                                expect(preStatus).toNot(contain("new file:"))
                                
                                expect(git!.add()).toNot(beNil())
                                
                                let postStatus = git!.status()
                                expect(postStatus).to(contain("Changes to be committed"))
                                expect(postStatus).to(contain("new file:   index.html"))
                            }
                        }
                        
                        context("commit") {
                            it("") {
                                Helper.addFile("index.html", directory: directory)
                                
                                expect(git!.add()).toNot(beNil())
                                
                                let commit = git!.commit()
                                expect(commit).to(contain("2 files changed, 4 insertions(+)"))
                            }
                        }
                        
                        context("pushToGitHub") {
                            
                            beforeEach {
                                _ = git!.initGitHub()
                                
                                Helper.addFile("index.html", directory: directory)
                                expect(git!.add()).toNot(beNil())
                                expect(git!.commit()).toNot(beNil())
                                git!.pushToGitHub()
                            }
                            
                            afterEach {
                                git!.removeGitHub()
                            }
                            
                            it("should provide a working tree clean status") {
                                expect(git!.status()).to(contain("working tree clean"))
                            }
                        }
                        
                        context("initGitHub") {
                            beforeEach {
                                _ = git!.initGitHub()
                            }
                            
                            afterEach {
                                git!.removeGitHub()
                            }
                            
                            it("saves a .gitignore file to the filesystem") {
                                let filePath = "\(directory.path)/.gitignore"
                                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                                expect(exists).to(beTrue(), description: "No gitignore found")
                            }
                            
                            it("results in a specific status") {
                                let status = git!.status()
                                expect(status).to(contain("On branch master"))
                                expect(status).to(contain("nothing to commit"))
                            }
                        }
                    }
                }
            }
        }
    }
}



