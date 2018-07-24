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
            var appDirectory: URL!
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            let credentials = Credentials(
                "atlastest",
                password: "1a2b3c4d",
                token: nil
            )


            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testGit")

                FileSystem.createDirectory(directory)

                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
            }

            afterEach {
                FileSystem.deleteDirectory(directory)
            }

            context("initialization") {

                var git: Git!

                beforeEach {
                    git = Git(directory, credentials: credentials)
                    appDirectory = git.directory
                }

                it("is not nil") {
                    expect(git).toNot(beNil())
                }

                it("runs git init on the directory") {
                    let gitPath = appDirectory.appendingPathComponent(".git").path
                    let exists = fileManager.fileExists(atPath: gitPath, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "No .git found")
                }
                
                it("provides a specific status") {
                    let status = git.status()
                    expect(status).to(contain("On branch master"))
                    expect(status).to(contain("nothing to commit"))
                }

//                it("initializes git annex") {
//                    let annexStatus = git.annexInfo()
//                    expect(annexStatus).to(contain("local annex keys: 0"))
//                    expect(annexStatus).to(contain("annexed files in working tree: 0"))
//                }

                context("when reinitialized") {

                    var git2: Git!

                    beforeEach {
                        git2 = Git(directory, credentials: credentials)
                    }

                    it("is not nil") {
                        expect(git2).toNot(beNil())
                    }

                }

                context("add") {
                    it("should do nothing when nothing is avalable to add") {
                        do {
                            try fileManager.removeItem(atPath: "\(appDirectory.path)/github.json")
                        } catch {}

                        let preStatus = git.status()
                        expect(preStatus).to(contain("nothing to commit"))
                        expect(preStatus).toNot(contain("Changes to be committed"))

                        expect(git.add()).toNot(beNil())

                        let postStatus = git.status()
                        expect(postStatus).to(contain("nothing to commit"))
                        expect(postStatus).toNot(contain("Changes to be committed"))
                    }

                    it("should add a file") {
                        Helper.addFile("index.html", directory: appDirectory)

                        let preStatus = git.status()
                        expect(preStatus).to(contain("index.html"))
                        expect(preStatus).to(contain("nothing added to commit"))

                        expect(preStatus).toNot(contain("Changes to be committed"))
                        expect(preStatus).toNot(contain("new file:"))

                        expect(git.add()).toNot(beNil())

                        let postStatus = git.status()
                        expect(postStatus).to(contain("Changes to be committed"))
                        expect(postStatus).to(contain("new file:   index.html"))
                    }
                }
                
                context("move") {
                    let fileName = "index.html"
                    let newFileName = "index2.html"
                    var filePath: String!

                    beforeEach {
                        filePath = appDirectory.appendingPathComponent(fileName).path
                        Helper.addFile(fileName, directory: appDirectory)
                    }
                    
                    it("returns false if file is not under version control") {
                        expect(git.move(filePath, into: appDirectory, renamedTo: newFileName)).to(beFalse())
                    }
                    
                    context("under version control") {
                        var result: Bool!
                        
                        beforeEach {
                            _ = git.add()
                            result = git.move(filePath, into: appDirectory, renamedTo: newFileName)
                        }
                        
                        it("returns true") {
                            expect(result).to(beTrue())
                        }
                        
                        it("moves the file") {
                            let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                            expect(exists).to(beFalse(), description: "Original file still found")

                            let newFilePath = appDirectory.appendingPathComponent(newFileName).path
                            let newExists = fileManager.fileExists(atPath: newFilePath, isDirectory: &isFile)
                            expect(newExists).to(beTrue(), description: "New file not found")
                        }
                    }
                }

                context("commit") {
                    it("commits successfully") {
                        Helper.addFile("index.html", directory: appDirectory)

                        expect(git.add()).toNot(beNil())

                        let commit = git.commit()
                        expect(commit).to(contain("1 file changed, 0 insertions(+), 0 deletions"))
                    }
                }

                context("pushToGitHub") {

                    let repositoryName = "testGitHub"
                    let credentials = Credentials(
                        "atlastest",
                        password: "1a2b3c4d",
                        token: nil
                    )
                    var gitHub: GitHub!

                    beforeEach {
                        if let token = GitHub.getAuthenticationToken(credentials) {
                            credentials.setAuthenticationToken(token: token)
                        }

                        gitHub = GitHub(credentials, repositoryName: repositoryName, git: git)
                        _ = gitHub.createRepository()

                        Helper.addFile("index.html", directory: appDirectory)
                        expect(git.status()).toNot(contain("working tree clean"))

                        expect(git.add()).toNot(beNil())
                        expect(git.commit()).toNot(beNil())

                        expect(git.status()).toNot(contain("Your branch is up-to-date with 'origin/master'"))
                    }

                    afterEach {
                        gitHub.deleteRepository()
                    }

                    it("should provide a working tree clean status") {
                        expect(git.status()).to(contain("working tree clean"))
                    }
                }

                context("writeGitIgnore") {

                    var gitIgnoreUrl: URL!

                    beforeEach {
                        gitIgnoreUrl = appDirectory.appendingPathComponent(".gitignore")
                        git.writeGitIgnore()
                    }

                    it("should write a gitignore file to the directory") {
                        let exists = fileManager.fileExists(atPath: gitIgnoreUrl.path, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No .gitignore found")
                    }

                    it("should include the specified gitignore files") {
                        do {
                            let contents = try String(contentsOf: gitIgnoreUrl, encoding: .utf8)
                            expect(contents).to(contain("credentials.json"))
                        } catch {
                            expect(false).to(beTrue(), description: "failed to read .gitignore")
                        }
                    }
                }
            }
        }
    }
}



