//
//  AtlasCorePurgeSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 7/9/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class AtlasCorePurgeSpec: QuickSpec {
    override func spec() {
        
        describe("AtlasCore") {
            
            var atlasCore: AtlasCore!
            
            var directory: URL!
            let username = "atlastest"
            let credentials = Credentials(
                username,
                password: "1a2b3c4d",
                token: nil
            )
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            var logEntries = 0
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ATLAS_CORE")
                FileSystem.createDirectory(directory)
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
                
                atlasCore = AtlasCore(directory)
            }
            
            afterEach {
                logEntries = 0
                atlasCore.closeSearch()
                atlasCore.deleteGitHubRepository()
                Helper.deleteBaseDirectory(directory)
            }
            
            context("with git and GitHub initialized") {
                beforeEach {
                    expect(atlasCore.initGitAndGitHub(credentials)).toNot(beNil())
                    
                    logEntries += 1
                    expect(
                        atlasCore.completedLogEntries().count
                    ).toEventually(equal(logEntries), timeout: 30)
                    
                    expect(atlasCore.validRepository()).toEventually(beTrue(), timeout: TimeInterval(30))
                    
                    expect(atlasCore.initSearch()).to(beTrue())
                }
                
                context("purge") {
                    
                    var project: Project!
                    let projectName = "ProjectPurge"
                    let fileName = "index.html"

                    let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                    var commitFolder: URL!
                    var committedFilePath: String!
                    var gitCommittedFilePath: String!
                    
                    beforeEach {
                        expect(atlasCore.log(full: true).count).to(equal(1))
                        
                        project = atlasCore.project(projectName)
                        
                        atlasCore.atlasCommit()
                        
                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                        ).toEventually(equal(logEntries), timeout: 30)
                        
                        let stagedDirectory = project.directory("staged")
                        Helper.addFile(fileName, directory: stagedDirectory)

                        atlasCore.atlasCommit()
                        
                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                        ).toEventually(equal(logEntries), timeout: 30)

                        expect(atlasCore.log(full: true).count).to(equal(3))
                    }
                    
                    it("should remove the staged file and atlasCore commit") {
                        let stagedFilePath = project.directory("staged").appendingPathComponent(fileName).path
                        let stagedFileRelativePath = "\(projectName)/staged/\(fileName)"
                        expect(atlasCore.purge([stagedFileRelativePath])).to(beTrue())
                        
                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                            ).toEventually(equal(logEntries), timeout: 30)
                        
                        let stillExists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                        expect(stillExists).to(beFalse(), description: "File still found in staged directory")
                        
                        expect(atlasCore.log(full: true).count).to(equal(2))
                    }
                    
                    context("after commit") {

                        beforeEach {
                            let slug = project.commitSlug(commitMessage)

                            expect(project.commitMessage(commitMessage)).to(beTrue())
                            expect(project.commitStaged()).to(beTrue())

                            atlasCore.atlasCommit()

                            logEntries += 1
                            expect(
                                atlasCore.completedLogEntries().count
                                ).toEventually(equal(logEntries), timeout: 30)

                            commitFolder = project.directory("committed").appendingPathComponent(slug)

                            committedFilePath = commitFolder.appendingPathComponent(fileName).path

                            let exists = fileManager.fileExists(atPath: committedFilePath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "File not found in commited directory")

                            gitCommittedFilePath = committedFilePath.replacingOccurrences(of: project.directory().path, with: projectName)

                            expect(atlasCore.purge([gitCommittedFilePath])).to(beTrue())

                            logEntries += 1
                            expect(
                                atlasCore.completedLogEntries().count
                                ).toEventually(equal(logEntries), timeout: 30)

                            let stillExists = fileManager.fileExists(atPath: committedFilePath, isDirectory: &isFile)

                            expect(stillExists).to(beFalse(), description: "File still found in commited directory")
                        }

                        it("removes the commit from the projects' log") {
                            let log = atlasCore.log()
                            expect(log.count).to(equal(0))
                        }

                        it("removes the commit folder") {
                            let exists = fileManager.fileExists(atPath: commitFolder.path, isDirectory: &isDirectory)
                            expect(exists).to(beFalse(), description: "Commit folder still found")
                        }

                        it("fails if the file can not be found") {
                            let nonexistentFilePath = gitCommittedFilePath.replacingOccurrences(of: fileName, with: "nonexistent")
                            expect(atlasCore.purge([nonexistentFilePath])).to(beFalse())
                        }
                    }

                    context("removing project folder") {

                        beforeEach {
                            expect(project.commitMessage(commitMessage)).to(beTrue())
                            expect(project.commitStaged()).to(beTrue())

                            atlasCore.atlasCommit()

                            logEntries += 1
                            expect(
                                atlasCore.completedLogEntries().count
                                ).toEventually(equal(logEntries), timeout: 30)

                            expect(atlasCore.purge([project.directory().path])).to(beTrue())

                            logEntries += 1
                            expect(
                                atlasCore.completedLogEntries().count
                                ).toEventually(equal(logEntries), timeout: 30)

                            let exists = fileManager.fileExists(atPath: project.directory().path, isDirectory: &isDirectory)

                            expect(exists).to(beFalse(), description: "Project folder still found")
                        }

                        it("removes all mentions from the log") {
                            let log = atlasCore.log()
                            expect(log.count).to(equal(0))
                        }
                    }
                }

                context("purge (removing two files when there are more than two files)") {

                    var project: Project!
                    let projectName = "ProjectPurgeTwo"
                    let fileName1 = "index1.html"
                    let fileName2 = "index2.html"
                    let fileName3 = "index3.html"
                    let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                    var commitFolder: URL!
                    var committedFilePath1: String!
                    var committedFilePath2: String!
                    var committedFilePath3: String!

                    beforeEach {
                        project = atlasCore.project(projectName)

                        let stagedDirectory = project.directory("staged")
                        Helper.addFile(fileName1, directory: stagedDirectory)
                        Helper.addFile(fileName2, directory: stagedDirectory)
                        Helper.addFile(fileName3, directory: stagedDirectory)

                        atlasCore.atlasCommit()

                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                            ).toEventually(equal(logEntries), timeout: 30)

                        let slug = project.commitSlug(commitMessage)

                        expect(project.commitMessage(commitMessage)).to(beTrue())
                        expect(project.commitStaged()).to(beTrue())

                        atlasCore.atlasCommit()
                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                            ).toEventually(equal(logEntries), timeout: 30)

                        commitFolder = project.directory("committed").appendingPathComponent(slug)

                        committedFilePath1 = commitFolder.appendingPathComponent(fileName1).path
                        committedFilePath2 = commitFolder.appendingPathComponent(fileName2).path
                        committedFilePath3 = commitFolder.appendingPathComponent(fileName3).path

                        let gitCommittedFilePath1 = committedFilePath1.replacingOccurrences(of: project.directory().path, with: projectName)
                        let gitCommittedFilePath2 = committedFilePath2.replacingOccurrences(of: project.directory().path, with: projectName)

                        expect(atlasCore.purge([gitCommittedFilePath1, gitCommittedFilePath2])).to(beTrue())

                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                            ).toEventually(equal(logEntries), timeout: 30)


                        let exists = fileManager.fileExists(atPath: committedFilePath1, isDirectory: &isFile)

                        expect(exists).to(beFalse(), description: "File 1 still found in commited directory")
                    }

                    it("removes the files from the commit folder") {
                        let exists2 = fileManager.fileExists(atPath: committedFilePath2, isDirectory: &isFile)
                        expect(exists2).to(beFalse(), description: "File 2 still found in commited directory")

                        let exists3 = fileManager.fileExists(atPath: committedFilePath3, isDirectory: &isFile)
                        expect(exists3).to(beTrue(), description: "File 3 not found in commited directory")
                    }

                    it("removes the file from the list in the commit's log") {
                        let log = atlasCore.log()
                        expect(log.count).to(equal(1))

                        expect(log.first?.files.count).to(equal(1))
                        expect(log.first?.files.first?.name).to(equal(fileName3))
                    }
                }
            }
        }
    }
}

