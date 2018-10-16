//
//  GitHubSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/14/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class GitHubSpec: QuickSpec {
    override func spec() {
        describe("GitHub") {
            
            let repositoryName = "testGitHub"
            var credentials: Credentials!
            var directory: URL!

            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(repositoryName)
                
                Helper.createBaseDirectory(directory)

                credentials = Credentials(
                    "atlastest",
                    email: "atlastest@puzzleschool.com",
                    password: "1a2b3c4d",
                    token: nil,
                    directory: directory
                )
            }
            
            afterEach {
                Helper.deleteBaseDirectory(directory)
            }

            context("initialized") {
                var appDirectory: URL!
                let fileManager = FileManager.default
                var isFile : ObjCBool = false
                var isDirectory : ObjCBool = true
                
                var git: Git!

                var gitHub: GitHub?
                
                beforeEach {
                    let filePath = directory.path
                    let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                    expect(exists).to(beTrue(), description: "No folder found")

                    Git.configure(credentials)

                    if let token = GitHub.getAuthenticationToken(credentials) {
                        credentials.setAuthenticationToken(token)
                    } else {
                        expect(false).to(beTrue(), description: "Failed to get token")
                    }
                    
                    git = Git(directory, credentials: credentials)
                    _ = git.initialize()
                    _ = git.runInit()
                    
                    gitHub = GitHub(credentials, repositoryName: repositoryName, git: git)
                    
                    appDirectory = git.directory
                }

                afterEach {
                    gitHub?.deleteRepository()
                }
                
                it("initializes") {
                    expect(gitHub).toNot(beNil())
                    expect(gitHub?.credentials).to(beIdenticalTo(credentials))
                    expect(gitHub?.repositoryName).to(equal(repositoryName))
                    expect(gitHub?.git).to(beIdenticalTo(git))
                }
                
                context("createRepository") {
                    
                    var result: Result?
                    
                    context("without token") {
                        beforeEach {
                            credentials.setAuthenticationToken(nil)
                            result = gitHub?.createRepository()
                        }
                        
                        it("should fail without token") {
                            expect(result?.success).to(beFalse())
                        }
                    }

                    context("with token") {
                        beforeEach {
                            result = gitHub?.createRepository()
                        }

                        it("should provide results") {
                            expect(result?.success).to(beTrue())
                        }
                        
                        it("should set the repository link") {
                            expect(gitHub?.repositoryLink).to(contain(credentials.username))
                            expect(gitHub?.repositoryLink).to(contain(repositoryName))
                        }
                    }
                    
                    context("with remotePath") {
                        let remoteName = "remote"
                        var url: URL!
                        
                        beforeEach {
                            url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(remoteName)
                            
                            Helper.createBaseDirectory(url)
                            
                            credentials.setAuthenticationToken(nil)
                            credentials.setRemotePath(url.path)
                            result = gitHub?.createRepository()
                        }
                        
                        afterEach {
                            Helper.deleteBaseDirectory(url)
                        }
                        
                        it("should provide results") {
                            expect(result?.success).to(beTrue())
                        }
                        
                        it("should set the repository link") {
                            expect(gitHub?.repositoryLink).to(contain(remoteName))
                        }
                    }
                    
//                    context("setPostCommitHook") {
//                        beforeEach {
//                            expect(gitHub!.setPostCommitHook().success).to(beTrue(), description: "Failed to set post-commit hook")
//                        }
//                        
//                        it("should create a post-commit hook") {
//                            let gitURL = appDirectory.appendingPathComponent(".git")
//                            let hooksURL = gitURL.appendingPathComponent("hooks")
//                            let postCommitPath = hooksURL.appendingPathComponent("post-commit").path
//                            let exists = fileManager.fileExists(atPath: postCommitPath, isDirectory: &isFile)
//                            expect(exists).to(beTrue(), description: "No post-commit found")
//                        }
//
//                    }
                }
                                
                context("setRepositoryLink") {
                    beforeEach {
                        _ = Glue.runProcess("git",
                            arguments: ["remote", "rm", "origin"],
                            currentDirectory: git?.directory
                        )
                        if let token = GitHub.getAuthenticationToken(credentials) {
                            credentials.setAuthenticationToken(token)
                        }
                    }
                    
                    it("should return false if the repository does not yet exist") {
                        expect(gitHub?.setRepositoryLink().success).to(beFalse())
                        expect(gitHub?.repositoryLink).to(beNil())
                    }

                    it("should return true if the repository already exists") {
                        expect(gitHub?.createRepository().success).to(beTrue())
                        expect(gitHub?.setRepositoryLink().success).to(beTrue())
                        expect(gitHub?.repositoryLink).to(equal("https://github.com/atlastest/testGitHub"))
                    }
                }
            
            }
            
            context("getAuthenticationToken") {
                
                it("should return the authentication token from GitHub") {
                    let token = GitHub.getAuthenticationToken(credentials)
                    expect(token).toNot(beNil())
                }
                
                it("should be nil if credentials are invalid") {
                    let badCredentials = Credentials("BAD", email: "BAD", password: "BAD", directory: directory)
                    let token = GitHub.getAuthenticationToken(badCredentials)
                    expect(token).to(beNil())
                }
                
                it("should be nil if credentials are missing a password") {
                    let badCredentials = Credentials(
                        credentials.username,
                        email: credentials.email,
                        directory: directory
                    )
                    let token = GitHub.getAuthenticationToken(badCredentials)
                    expect(token).to(beNil())
                }
            }

        }
    }
}

