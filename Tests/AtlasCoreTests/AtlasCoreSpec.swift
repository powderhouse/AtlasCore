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

            let username = "atlastest"
            var credentials: Credentials!
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            var logEntries = 0
            var providedLogMessages: [String] = []
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ATLAS_CORE")
                Helper.createBaseDirectory(directory)
                
                credentials = Credentials(
                    username,
                    directory: directory
                )
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")

                let providedLog: (_ message: String) -> Void = { (message) in
                    providedLogMessages.append(message)
                }
                
                atlasCore = AtlasCore(directory, log: providedLog)
            }
            
            afterEach {
                logEntries = 0
                providedLogMessages = []
                atlasCore.closeSearch()
                while FileSystem.fileExists(directory, isDirectory: true) {
                    Helper.deleteBaseDirectory(directory)
                }
            }

            context("getDefaultBaseDirectory") {
                it("should provide the Application Support folder") {
                    let path = atlasCore.getDefaultBaseDirectory().path
                    expect(path).to(contain("Application Support"))
                }
            }

            context("with git and GitHub initialized") {
                beforeEach {
                    expect(atlasCore.initGitAndGitHub(credentials)).toNot(beNil())
                    
                    logEntries += 1
                    expect(
                        atlasCore.completedLogEntries().count
                    ).toEventually(equal(logEntries), timeout: 10)
                    
                    expect(atlasCore.validRepository()).toEventually(beTrue(), timeout: 10)

                    expect(atlasCore.initSearch().success).to(beTrue())
                }
                
                it("logs progress to the provided log") {
                    expect(providedLogMessages.count).to(beGreaterThan(0))
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
                    if let readmeFile = atlasCore.appDirectory?.appendingPathComponent(Project.readme) {
                        let exists = fileManager.fileExists(atPath: readmeFile.path, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No \(Project.readme) found")
                    } else {
                        expect(false).to(beTrue(), description: "Atlas directory was not set")
                    }
                }

                it("successfully syncs with GitHub after a commit") {
                    expect(atlasCore.remote()).toEventually(contain(AtlasCore.originName), timeout: 10)

                    let projectName = "Project"
                    let file = "index1.html"

                    let fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                    _ = FileSystem.createDirectory(fileDirectory)
                    Helper.addFile(file, directory: fileDirectory)

                    expect(atlasCore.initProject(projectName)).to(beTrue())
                    let project = atlasCore.project(projectName)

                    let filePath = fileDirectory.appendingPathComponent(file).path
                    expect(project?.copyInto([filePath]).success).to(beTrue())
                    _ = atlasCore.atlasCommit()

                    logEntries += 1
                    expect(
                        atlasCore.completedLogEntries().count
                    ).toEventually(equal(logEntries), timeout: 10)

                    let logUrl = atlasCore.userDirectory!.appendingPathComponent("log.txt")
                    let exists = fileManager.fileExists(atPath: logUrl.path, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "Unable to find log")

                    expect(try? String(contentsOf: logUrl, encoding: .utf8)).toEventually(contain("</ENDENTRY>"), timeout: 10)

                    expect(project?.commitMessage("Commit Message")).to(beTrue())
                    expect(project?.commitStaged().success).to(beTrue())
                    _ = atlasCore.commitChanges()

                    logEntries += 1
                    expect(
                        atlasCore.completedLogEntries().count
                    ).toEventually(equal(logEntries), timeout: 10)

                    expect(try? String(contentsOf: logUrl, encoding: .utf8)).toEventually(contain("Branch 'master' set up to track remote branch 'master' from 'origin'."), timeout: 10)
                }

                it("initializes search successfully") {
                    expect(atlasCore.search?.documentCount()).to(equal(0))

                    let searchIndexPath = atlasCore.userDirectory?.appendingPathComponent(Search.indexFileName).path
                    let exists = fileManager.fileExists(atPath: searchIndexPath!, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "No search index found")
                }

                context("future instances of AtlasCore") {
                    var atlasCore2: AtlasCore!

                    beforeEach {
                        atlasCore.closeSearch()

                        let searchIndexPath = atlasCore.userDirectory?.appendingPathComponent(Search.indexFileName).path
                        let exists = fileManager.fileExists(atPath: searchIndexPath!, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No search index found")

                        atlasCore2 = AtlasCore(directory)
                        let initializationResult = atlasCore2.initialize()
                        expect(initializationResult.success).to(beTrue(), description: "\(initializationResult) was not successful")
                    }

                    afterEach {
                        atlasCore2.closeSearch()
                    }

                    it("initializes GitHub") {
                        let repository = atlasCore2.gitHubRepository()
                        expect(repository).to(contain(AtlasCore.originName))
                    }

                    it("automatically inits search") {
                        expect(atlasCore2.search).toNot(beNil())

                        let searchIndexPath = atlasCore2.userDirectory?.appendingPathComponent(Search.indexFileName).path
                        let exists = fileManager.fileExists(atPath: searchIndexPath!, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No search index found")
                    }

                    context("initialized again") {
                        var result: Result!
                        var newCredentials: Credentials!

                        beforeEach {
                            newCredentials = Credentials(
                                "atlastest",
                                password: "1a2b3c4d",
                                token: nil,
                                directory: directory
                            )
                            result = atlasCore.initGitAndGitHub(newCredentials)
                        }

                        it("allows you to initialize again") {
                            expect(result.success).to(beTrue())
                        }

                        it("sets the github repository link properly") {
                            expect(atlasCore2.gitHubRepository()).to(contain(AtlasCore.originName))
                        }
                    }

                    context("initialized again after local directory deleted") {
                        var result: Result!
                        var newCredentials: Credentials!

                        beforeEach {
                            let userDirectory = directory.appendingPathComponent(credentials.username)
                            let appDirectory = userDirectory.appendingPathComponent(AtlasCore.appName)
                            Helper.deleteBaseDirectory(appDirectory)
                            
                            newCredentials = Credentials(
                                    "atlastest",
                                    password: "1a2b3c4d",
                                    token: nil,
                                    directory: userDirectory
                            )
                            
                            result = atlasCore.initGitAndGitHub(newCredentials)
                        }

                        it("allows you to initialize again") {
                            expect(result.success).to(beTrue())
                        }

                        it("sets the github repository link properly") {
                            expect(atlasCore2.gitHubRepository()).to(contain(AtlasCore.originName))
                        }
                    }


                }

                context("initProject") {
                    let projectName = "New Project"

                    beforeEach {
                        _ = atlasCore.initProject(projectName)
                    }

                    it("should create a folder in the Atlas directory with a readme") {
                        if let projectFolder = atlasCore.appDirectory?.appendingPathComponent(projectName) {
                            let exists = fileManager.fileExists(atPath: projectFolder.path, isDirectory: &isDirectory)
                            expect(exists).to(beTrue(), description: "No project folder found for \(projectName)")
                        } else {
                            expect(false).to(beTrue(), description: "Atlas directory was not set")
                        }
                    }

                    it("should create three subfolders, each with a readme, in the project folder") {
                        if let projectFolder = atlasCore.appDirectory?.appendingPathComponent(projectName) {
                            for folderName in ["unstaged", "staged", "committed"] {
                                let subfolderURL = projectFolder.appendingPathComponent(folderName)
                                let exists = fileManager.fileExists(atPath: subfolderURL.path, isDirectory: &isDirectory)
                                expect(exists).to(beTrue(), description: "No project subfolder found: \(folderName)")

                                let readmePath = subfolderURL.appendingPathComponent(Project.readme).path
                                let readmeExists = fileManager.fileExists(atPath: readmePath, isDirectory: &isFile)
                                expect(readmeExists).to(beTrue(), description: "No readme found in subfolder: \(folderName)")
                            }
                        } else {
                            expect(false).to(beTrue(), description: "Atlas directory was not set")
                        }
                    }
                }

                context("complex setup") {

                    let project1Name = "Project"
                    let project2Name = "AnotherProject"
                    var project1: Project!
                    var project2: Project!

                    let file1 = "index1.html"
                    let file2 = "index2.html"
                    let file3 = "index3.html"
                    var fileDirectory: URL!

                    let message1 = "The first commit"
                    let message2 = """
The second commit

Multiline
"""
                    var slug1 = ""
                    var slug2 = ""

                    beforeEach {
                        fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                        _ = FileSystem.createDirectory(fileDirectory)
                        Helper.addFile(file1, directory: fileDirectory)
                        Helper.addFile(file2, directory: fileDirectory)
                        Helper.addFile(file3, directory: fileDirectory)

                        expect(atlasCore.initProject(project2Name)).to(beTrue())

                        project1 = atlasCore.project(project1Name)
                        project2 = atlasCore.project(project2Name)

                        let filePath1 = fileDirectory.appendingPathComponent(file1).path
                        expect(project1?.copyInto([filePath1]).success).to(beTrue())
                        _ = atlasCore.atlasCommit()

                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                        ).toEventually(equal(logEntries), timeout: 10)

                        slug1 = project1!.commitSlug(message1)
                        slug2 = project2!.commitSlug(message2)

                        expect(project1?.commitMessage(message1)).to(beTrue())
                        expect(project1?.commitStaged().success).to(beTrue())
                        _ = atlasCore.commitChanges(message1)

                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                        ).toEventually(equal(logEntries), timeout: 10)

                        let filePath2 = fileDirectory.appendingPathComponent(file2).path
                        expect(project2?.copyInto([filePath2]).success).to(beTrue())

                        let filePath3 = fileDirectory.appendingPathComponent(file3).path
                        expect(project2?.copyInto([filePath3]).success).to(beTrue())

                        _ = atlasCore.atlasCommit()

                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                        ).toEventually(equal(logEntries), timeout: 10)

                        expect(project2?.commitMessage(message2)).to(beTrue())
                        expect(project2?.commitStaged().success).to(beTrue())
                        _ = atlasCore.commitChanges(message2)

                        expect(atlasCore.log().count).toEventually(equal(2), timeout: 10)
                    }

                    context("log") {

                        it("should return an array of commit information ordered by date submitted") {
                            let log = atlasCore.log()

                            if let lastCommit = log.last {
                                expect(lastCommit.message).to(contain(message2))
                                expect(lastCommit.files.count).to(equal(2))
                                if let firstFile = lastCommit.files.first {
                                    expect(firstFile.name).to(equal(file2))
                                    expect(firstFile.url).to(equal("/\(project2Name)/committed/\(slug2)/\(file2)"))
                                }
                            }
                        }

                        it("should only return the commits for a project if specified") {
                            expect(atlasCore.log(projectName: project1Name).count).toEventually(equal(1), timeout: 10)

                            let log = atlasCore.log(projectName: project1Name)

                            if let lastCommit = log.last {
                                expect(lastCommit.message).to(contain(message1))
                                expect(lastCommit.files.count).to(equal(1))
                                if let firstFile = lastCommit.files.first {
                                    expect(firstFile.name).to(equal(file1))
                                    expect(firstFile.url).to(equal("/\(project1Name)/committed/\(slug1)/\(file1)"))
                                } else {
                                    expect(false).to(beTrue(), description: "file missing")
                                }

                                expect(lastCommit.projects.count).to(equal(1))
                                if let project = lastCommit.projects.first {
                                    expect(project.name).to(equal("Project"))
                                } else {
                                    expect(false).to(beTrue(), description: "project missing")
                                }
                            }
                        }

                        it("should only return a specific commits if a commitSlug is specified") {
                            let log = atlasCore.log(commitSlugFilter: [slug2])
                            expect(log.count).toEventually(equal(1), timeout: 10)

                            if let lastCommit = log.last {
                                expect(lastCommit.message).to(contain(message2))
                                expect(lastCommit.files.count).to(equal(2))
                            }
                        }

                        it("should only return multiple specific commits if multiple commitSlugs are specified") {
                            let log = atlasCore.log(commitSlugFilter: [slug1, slug2])
                            expect(log.count).toEventually(equal(2), timeout: 10)

                            if let firstCommit = log.first {
                                expect(firstCommit.message).to(contain(message1))
                                expect(firstCommit.files.count).to(equal(1))
                            }
                        }


                        it("should create syncLogEntries") {
                            expect(atlasCore.syncLogEntries().count).to(equal(6))
                            expect(atlasCore.syncLog()).toNot(contain("Bad file descriptor"))
                        }

                    }

                    context("syncLogEntries") {
                        it("should create more syncLogEntries if sync is called") {
                            expect(atlasCore.syncLogEntries().count).toEventually(equal(6))
                            atlasCore.sync()
                            expect(atlasCore.syncLogEntries().count).toEventually(equal(7))
                        }
                    }

                    context("search") {
                        beforeEach {
                            expect(atlasCore.initSearch().success).to(beTrue())
                        }

                        it("initializes correctly, consuming existing files") {
                            expect(atlasCore.search.documentCount()).to(beGreaterThan(0))
                        }

                        it("processes a new file") {

                        }
                    }
                }

                context("projects") {

                    beforeEach {
                        _ = atlasCore.initProject("Project 1")
                        _ = atlasCore.initProject("\\\"Project a\\\"")
                        _ = atlasCore.initProject("\"A Project\"")
                        _ = atlasCore.atlasCommit()

                        logEntries += 1
                        expect(
                            atlasCore.completedLogEntries().count
                        ).toEventually(equal(logEntries), timeout: 10)
                    }

                    it("should return an array of the projects") {
                        let projects = atlasCore.projects().map { $0.name }.sorted()
                        expect(projects).to(equal(["\"A Project\"", "Project 1", "\\\"Project a\\\""]))
                    }

                    it("should ignore files in the atlas directory") {
                        Helper.addFile("index.html", directory: atlasCore.appDirectory!)

                        let projects = atlasCore.projects().map { $0.name }.sorted()
                        expect(projects).to(equal(["\"A Project\"", "Project 1", "\\\"Project a\\\""]))
                    }

                    it("should ignore folders in the atlas directory that do not have a readme.md") {
                        _ = FileSystem.createDirectory((atlasCore.appDirectory!.appendingPathComponent("misc")))

                        let projects = atlasCore.projects().map { $0.name }.sorted()
                        expect(projects).to(equal(["\"A Project\"", "Project 1", "\\\"Project a\\\""]))
                    }

                }
            }
        }
    }
}

