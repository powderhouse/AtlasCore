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
            let credentials = Credentials(
                username,
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
                atlasCore.closeSearch()
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
                    expect(atlasCore.initGitAndGitHub(credentials)).toNot(beNil())
                    expect(atlasCore.validRepository()).toEventually(beTrue(), timeout: TimeInterval(30))
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
                    if let readmeFile = atlasCore.atlasDirectory?.appendingPathComponent(Project.readme) {
                        let exists = fileManager.fileExists(atPath: readmeFile.path, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No \(Project.readme) found")
                    } else {
                        expect(false).to(beTrue(), description: "Atlas directory was not set")
                    }
                }
                
                it("successfully syncs with GitHub after a commit") {
                    expect(atlasCore.remote()).toEventually(contain("github.com/\(username)/Atlas.git"), timeout: TimeInterval(10))
                    
                    let projectName = "General Project"
                    let file = "index1.html"

                    let fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                    FileSystem.createDirectory(fileDirectory)
                    Helper.addFile(file, directory: fileDirectory)

                    expect(atlasCore.initProject(projectName)).to(beTrue())
                    let project = atlasCore.project(projectName)
                    
                    let filePath = fileDirectory.appendingPathComponent(file).path
                    expect(project?.copyInto([filePath])).to(beTrue())
                    atlasCore.atlasCommit()

                    let logUrl = atlasCore.userDirectory!.appendingPathComponent("log.txt")
                    let exists = fileManager.fileExists(atPath: logUrl.path, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "Unable to find log")

                    expect(try? String(contentsOf: logUrl, encoding: .utf8)).toEventually(contain("</ENDENTRY>"), timeout: TimeInterval(10))

                    expect(project?.commitMessage("Commit Message")).to(beTrue())
                    expect(project?.commitStaged()).to(beTrue())
                    atlasCore.commitChanges()
                    
                    expect(try? String(contentsOf: logUrl, encoding: .utf8)).toEventually(contain("Branch master set up to track remote branch master from origin."), timeout: TimeInterval(30))
                }
                
                it("initializes search successfully") {
                    expect(atlasCore.initSearch()).to(beTrue())
                    expect(atlasCore.search?.documentCount()).to(equal(0))
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

                context("initProject") {
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
                    
                    let project1Name = "General Project"
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
                        
                        slug1 = project1!.commitSlug(message1)
                        slug2 = project2!.commitSlug(message2)

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
                        
                        expect(atlasCore.log().count).toEventually(equal(2), timeout: TimeInterval(30))
                    }
                    
                    context("log") {

                        it("should return an array of commit information ordered by date submitted") {
                            let log = atlasCore.log()
     
                            if let lastCommit = log.last {
                                expect(lastCommit.message).to(contain(message2))
                                expect(lastCommit.files.count).to(equal(2))
                                if let firstFile = lastCommit.files.first {
                                    expect(firstFile.name).to(equal(file2))
                                    expect(firstFile.url).to(equal("https://raw.githubusercontent.com/\(credentials.username)/Atlas/\(lastCommit.hash)/\(project2Name)/committed/\(slug2)/\(file2)"))
                                }
                            }
                        }
                        
                        it("should only return the commits for a project if specified") {
                            expect(atlasCore.log(projectName: project1Name).count).toEventually(equal(1), timeout: TimeInterval(30))
                            
                            let log = atlasCore.log(projectName: project1Name)
                            
                            if let lastCommit = log.last {
                                expect(lastCommit.message).to(contain(message1))
                                expect(lastCommit.files.count).to(equal(1))
                                if let firstFile = lastCommit.files.first {
                                    expect(firstFile.name).to(equal(file1))
                                    expect(firstFile.url).to(equal("https://raw.githubusercontent.com/\(credentials.username)/Atlas/\(lastCommit.hash)/\(project1Name)/committed/\(slug1)/\(file1)"))
                                } else {
                                    expect(false).to(beTrue(), description: "file missing")
                                }
                                
                                expect(lastCommit.projects.count).to(equal(1))
                                if let project = lastCommit.projects.first {
                                    expect(project.name).to(equal("General Project"))
                                } else {
                                    expect(false).to(beTrue(), description: "project missing")
                                }
                            }
                        }
                        
                        it("should create syncLogEntries") {
                            expect(atlasCore.syncLogEntries().count).to(equal(4))
                        }
                    
                    }
                    
                    context("syncLogEntries") {
                        it("should create more syncLogEntries if sync is called") {
                            expect(atlasCore.syncLogEntries().count).toEventually(equal(4))
                            atlasCore.sync()
                            expect(atlasCore.syncLogEntries().count).toEventually(equal(5))
                        }
                    }
                    
//                    context("search") {
//                        beforeEach {
//                            expect(atlasCore.initSearch()).to(beTrue())
//                        }
//                        
//                        it("initializes correctly, consuming existing files") {
//                            expect(atlasCore.search.documentCount()).to(beGreaterThan(0))
//                        }
//                        
//                        it("processes a new file") {
//                            
//                        }
//                    }
                }
                
                context("purge") {

                    var project: Project!
                    let projectName = "General Project"
                    let fileName = "index.html"
                    let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                    var commitFolder: URL!
                    var committedFilePath: String!
                    var gitCommittedFilePath: String!

                    beforeEach {
                        expect(atlasCore.initGitAndGitHub(credentials)).to(beTrue())

                        project = atlasCore.project(projectName)
                        atlasCore.atlasCommit()

                        expect(atlasCore.log(full: true).count).to(equal(1))

                        let stagedDirectory = project.directory("staged")
                        Helper.addFile(fileName, directory: stagedDirectory)

                        atlasCore.atlasCommit()
                    }
                    
                    it("should remove the staged file and atlasCore commit") {
                        let stagedFilePath = project.directory("staged").appendingPathComponent(fileName).path
                        let exists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "File not found in staged directory")

                        expect(atlasCore.log(full: true).count).to(equal(2))

                        let stagedFileRelativePath = "\(projectName)/staged/\(fileName)"
                        expect(atlasCore.purge([stagedFileRelativePath])).to(beTrue())
                        
                        let stillExists = fileManager.fileExists(atPath: stagedFilePath, isDirectory: &isFile)
                        expect(stillExists).to(beFalse(), description: "File still found in staged directory")
                        
                        expect(atlasCore.log(full: true).count).to(equal(1))
                    }
                    
                    context("after commit") {

                        beforeEach {
                            let slug = project.commitSlug(commitMessage)

                            expect(project.commitMessage(commitMessage)).to(beTrue())
                            expect(project.commitStaged()).to(beTrue())

                            atlasCore.atlasCommit()

                            commitFolder = project.directory("committed").appendingPathComponent(slug)

                            committedFilePath = commitFolder.appendingPathComponent(fileName).path

                            let exists = fileManager.fileExists(atPath: committedFilePath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "File not found in commited directory")

                            gitCommittedFilePath = committedFilePath.replacingOccurrences(of: project.directory().path, with: projectName)
                            expect(atlasCore.purge([gitCommittedFilePath])).to(beTrue())
                        }

                        it("removes the files from the commit folder") {
                            let exists = fileManager.fileExists(atPath: committedFilePath, isDirectory: &isFile)
                            expect(exists).to(beFalse(), description: "File still found in commited directory")
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
                }

                context("purge (removing two files with more than two files)") {

                    var project: Project!
                    let projectName = "General Project"
                    let fileName1 = "index1.html"
                    let fileName2 = "index2.html"
                    let fileName3 = "index3.html"
                    let commitMessage = "Here is a commit I wanted to commit so I clicked commit and it committed the commit!"
                    var commitFolder: URL!
                    var committedFilePath1: String!
                    var committedFilePath2: String!
                    var committedFilePath3: String!

                    beforeEach {
                        expect(atlasCore.initGitAndGitHub(credentials)).to(beTrue())

                        project = atlasCore.project(projectName)
                        let stagedDirectory = project.directory("staged")
                        Helper.addFile(fileName1, directory: stagedDirectory)
                        Helper.addFile(fileName2, directory: stagedDirectory)
                        Helper.addFile(fileName3, directory: stagedDirectory)

                        atlasCore.atlasCommit()

                        let slug = project.commitSlug(commitMessage)

                        expect(project.commitMessage(commitMessage)).to(beTrue())
                        expect(project.commitStaged()).to(beTrue())

                        atlasCore.atlasCommit()

                        commitFolder = project.directory("committed").appendingPathComponent(slug)

                        committedFilePath1 = commitFolder.appendingPathComponent(fileName1).path
                        committedFilePath2 = commitFolder.appendingPathComponent(fileName2).path
                        committedFilePath3 = commitFolder.appendingPathComponent(fileName3).path

                        let gitCommittedFilePath1 = committedFilePath1.replacingOccurrences(of: project.directory().path, with: projectName)
                        let gitCommittedFilePath2 = committedFilePath2.replacingOccurrences(of: project.directory().path, with: projectName)
                        expect(atlasCore.purge([gitCommittedFilePath1, gitCommittedFilePath2])).to(beTrue())
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

                        expect(log.first?.files.count).to(equal(1))
                        expect(log.first?.files.first?.name).to(equal(fileName3))
                    }
                }

                context("projects") {

                    beforeEach {
                        _ = atlasCore.initProject("Project 1")
                        _ = atlasCore.initProject("\\\"Project a\\\"")
                        _ = atlasCore.initProject("\"A Project\"")
                        atlasCore.atlasCommit()
                    }

                    it("should return an array of the projects") {
                        let projects = atlasCore.projects().map { $0.name }.sorted()
                        expect(projects).to(equal(["\"A Project\"", "Project 1", "\\\"Project a\\\""]))
                    }
                    
                    it("should ignore files in the atlas directory") {
                        Helper.addFile("index.html", directory: atlasCore.atlasDirectory!)

                        let projects = atlasCore.projects().map { $0.name }.sorted()
                        expect(projects).to(equal(["\"A Project\"", "Project 1", "\\\"Project a\\\""]))
                    }
                    
                    it("should ignore folders in the atlas directory that do not have a readme.md") {
                        FileSystem.createDirectory((atlasCore.atlasDirectory!.appendingPathComponent("misc")))

                        let projects = atlasCore.projects().map { $0.name }.sorted()
                        expect(projects).to(equal(["\"A Project\"", "Project 1", "\\\"Project a\\\""]))
                    }
                    
                }
            }
        }
    }
}

