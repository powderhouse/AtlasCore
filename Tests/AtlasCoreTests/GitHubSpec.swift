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
            let credentials = Credentials(
                "atlastest",
                password: "1a2b3c4d",
                token: nil
            )

            context("initialized") {
                var directory: URL!
                let fileManager = FileManager.default
                var isFile : ObjCBool = false
                var isDirectory : ObjCBool = true
                
                var git: Git!

                var gitHub: GitHub?
                
                beforeEach {
                    directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(repositoryName)
                    
                    FileSystem.createDirectory(directory)
                    let filePath = directory.path
                    let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                    expect(exists).to(beTrue(), description: "No folder found")

                    git = Git(directory)

                    gitHub = GitHub(credentials, repositoryName: repositoryName, git: git)
                }

                afterEach {
                    FileSystem.deleteDirectory(directory)
                    gitHub?.deleteRepository()
                }
                
                it("initializes") {
                    expect(gitHub).toNot(beNil())
                    expect(gitHub?.credentials).to(beIdenticalTo(credentials))
                    expect(gitHub?.repositoryName).to(equal(repositoryName))
                    expect(gitHub?.git).to(beIdenticalTo(git))
                }
                
                context("createRepository") {
                    
                    var results: [String:Any]?
                    
                    beforeEach {
                        results = gitHub?.createRepository()
                    }
                    
                    it("should fail without token") {
                        expect(results).to(beNil())
                    }
                    
                    context("with token") {
                    
                        beforeEach {
                            if let token = GitHub.getAuthenticationToken(credentials) {
                                credentials.setAuthenticationToken(token: token)
                            }
                            results = gitHub?.createRepository()
                        }

                        it("should provide results") {
                            expect(results).toNot(beNil())
                        }
                        
                        it("should set the repository link") {
                            expect(gitHub?.repositoryLink).to(contain(credentials.username))
                            expect(gitHub?.repositoryLink).to(contain(repositoryName))
                        }
                    }
                    
                    context("setPostCommitHook") {
                        beforeEach {
                            if !gitHub!.setPostCommitHook() {
                                expect(false).to(beTrue(), description: "Failed to set post-commit hook")
                            }
                        }
                        
                        it("should create a post-commit hook") {
                            let gitURL = directory.appendingPathComponent(".git")
                            let hooksURL = gitURL.appendingPathComponent("hooks")
                            let postCommitPath = hooksURL.appendingPathComponent("post-commit").path
                            let exists = fileManager.fileExists(atPath: postCommitPath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "No post-commit found")
                        }

                    }
                }
                
                context("url") {
                    beforeEach {
                        if let token = GitHub.getAuthenticationToken(credentials) {
                            credentials.setAuthenticationToken(token: token)
                        }
                        _ = gitHub?.createRepository()
                    }
                    
                    it("should return the url for the repository") {
                        let url = gitHub?.url()
                        expect(url).to(contain(credentials.username))
                        expect(url).to(contain(repositoryName))
                        if let token = credentials.token {
                            expect(url).toNot(contain(token))
                        } else {
                            expect(false).to(beTrue(), description: "token is nil")
                        }
                    }
                }
                
                context("setRepositoryLink") {
                    
                    it("should return false if the repository does not yet exist") {
                        expect(gitHub?.setRepositoryLink()).to(beFalse())
                        expect(gitHub?.repositoryLink).to(beNil())
                    }

                    it("should return true if the repository does not yet exist") {
                        _ = gitHub?.createRepository()
                        expect(gitHub?.setRepositoryLink()).to(beTrue())
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
                    let badCredentials = Credentials("BAD", password: "BAD")
                    let token = GitHub.getAuthenticationToken(badCredentials)
                    expect(token).to(beNil())
                }
                
                it("should be nil if credentials are missing a password") {
                    let badCredentials = Credentials(credentials.username)
                    let token = GitHub.getAuthenticationToken(badCredentials)
                    expect(token).to(beNil())
                }
            }

        }
    }
}

