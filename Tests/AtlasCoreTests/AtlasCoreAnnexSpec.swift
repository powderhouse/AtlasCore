//
//  AtlasCoreAnnexSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 8/2/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class AtlasCoreAnnexSpec: CoreSpec {
    override func spec() {
        
        describe("AtlasCoreAnnex") {
            
            var atlasCore: AtlasCore!
            
            var directory: URL!
            
            let username = "atlastest"
            let email = "atlastest@puzzleschool.com"
            var credentials: Credentials!
            
            let fileManager = FileManager.default
//            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            var logEntries = 0
            
            let project1Name = "Project"
            let project2Name = "AnotherProject"
            var project1: Project!
            var project2: Project!
            
            let file1 = "index1.html"
            let file2 = "index2.html"
            let file3 = "index3.html"
            let file4 = "index4.html"
            var fileDirectory: URL!
            
            let message1 = "The first commit"
            let message2 = """
The second commit

Multiline
"""
            var slug1 = ""
            var slug2 = ""
            
            var s3Bucket: String!
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ATLAS_CORE")

                while FileSystem.fileExists(directory, isDirectory: true) {
                    Helper.deleteBaseDirectory(directory)
                }
                
                // Ugh how do you avoid this hardcoding?
                S3Helper.deleteBucket("\(GitAnnex.groupName)-\(username)")

                Helper.createBaseDirectory(directory)
                
                credentials = Credentials(
                    username,
                    email: email,
                    s3AccessKey: "test",
                    s3SecretAccessKey: "test",
                    directory: directory
                )
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
                
                atlasCore = AtlasCore(directory)
                
                expect(atlasCore.initGitAndGitHub(credentials).success).to(beTrue())
                s3Bucket = atlasCore.git?.gitAnnex?.s3Bucket
                
                logEntries += 1
                expect(
                    atlasCore.completedLogEntries().count
                ).toEventually(equal(logEntries), timeout: 10)
                
                expect(atlasCore.validRepository()).toEventually(beTrue(), timeout: 10)
                
                fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                _ = FileSystem.createDirectory(fileDirectory)
                Helper.addFile(file1, directory: fileDirectory, contents: file1)
                Helper.addFile(file2, directory: fileDirectory, contents: file2)
                Helper.addFile(file3, directory: fileDirectory, contents: file3)
                
                expect(atlasCore.initProject(project2Name)).to(beTrue())
                
                project1 = atlasCore.project(project1Name)
                project2 = atlasCore.project(project2Name)
                
                let filePath1 = fileDirectory.appendingPathComponent(file1).path
                expect(project1?.copyInto([filePath1]).success).to(beTrue())
                expect(atlasCore.atlasCommit().success).to(beTrue())
                
                logEntries += 1
                expect(
                    atlasCore.completedLogEntries().count
                ).toEventually(equal(logEntries), timeout: 10)
                
                slug1 = project1!.commitSlug(message1)
                slug2 = project2!.commitSlug(message2)
                
                expect(project1?.commitMessage(message1)).to(beTrue())
                expect(project1?.commitStaged().success).to(beTrue())
                
                expect(atlasCore.commitChanges(message1).success).to(beTrue())
                logEntries += 1
                expect(
                    atlasCore.completedLogEntries().count
                ).toEventually(equal(logEntries), timeout: 10)
                
                let filePath2 = fileDirectory.appendingPathComponent(file2).path
                expect(project2?.copyInto([filePath2]).success).to(beTrue())
                
                let filePath3 = fileDirectory.appendingPathComponent(file3).path
                expect(project2?.copyInto([filePath3]).success).to(beTrue())
                
                for identifier in [file2, file3] {
                    let file = project2.directory(Project.staged).appendingPathComponent(identifier)
                    expect(FileSystem.fileExists(file)).toEventually(beTrue())
                }

                expect(atlasCore.atlasCommit().success).to(beTrue())
                
                logEntries += 1
                expect(
                    atlasCore.completedLogEntries().count
                ).toEventually(equal(logEntries), timeout: 10)
                
                expect(project2?.commitMessage(message2)).to(beTrue())
                expect(project2?.commitStaged().success).to(beTrue())
                expect(atlasCore.commitChanges(message2).success).to(beTrue())

                logEntries += 1
                expect(
                    atlasCore.completedLogEntries().count
                ).toEventually(equal(logEntries), timeout: 10)

                atlasCore.sync()
                logEntries += 1
                expect(
                    atlasCore.completedLogEntries().count
                ).toEventually(equal(logEntries), timeout: 10)
            }
            
            afterEach {
                logEntries = 0
                while FileSystem.fileExists(directory, isDirectory: true) {
                    Helper.deleteBaseDirectory(directory)
                }
                if let s3Bucket = atlasCore.git?.gitAnnex?.s3Bucket {
                    S3Helper.deleteBucket(s3Bucket)
                }
            }
            
            it("should sync with s3, reflecting files and directory structures, and then remove files locally") {
                for identifier in [slug1, slug2, file1, file2, file3] {
                    let remoteFiles = atlasCore.remoteFiles()
                    let matches = remoteFiles.filter { $0.contains(identifier) }.count
                    expect(matches).toEventually(beGreaterThan(0), description: "\(identifier) not found")
                }
                
                for identifier in [file2, file3] {
                    let commitDir = project2.directory(Project.committed).appendingPathComponent(slug2)
                    let file = commitDir.appendingPathComponent(identifier)
                    expect(FileSystem.fileExists(file)).toEventually(beFalse())
                }
            }

            context("purging files and projects") {

                it("should remove the file from S3 when purged") {

                    let relativePath = "\(project2.name!)/committed/\(slug2)/\(file2)"

                    let x = atlasCore.purge([relativePath])
                    expect(x.success).to(beTrue())

                    expect(S3Helper.listObjects(s3Bucket)).toEventuallyNot(contain(file2), timeout: 30)

                    let objects = S3Helper.listObjects(s3Bucket)

                    for identifier in [slug1, slug2, file1, file3] {
                        expect(objects).to(contain(identifier), description: "\(identifier) not found")
                    }
                }

                it("should remove project and all files from S3 when the project is deleted") {
                    expect(atlasCore.purge([project2.name]).success).to(beTrue())

                    for identifier in [slug2, file2, file3] {
                        expect(S3Helper.listObjects(s3Bucket)).toEventuallyNot(contain(identifier), timeout: 30, description: "\(identifier) still found")

                    }

                    let objects = S3Helper.listObjects(s3Bucket)

                    for identifier in [slug1, file1] {
                        expect(objects).to(contain(identifier), description: "\(identifier) not found")
                    }
                }
            }

            context("deleting local repository and then reinitializing") {

                var atlasCore2: AtlasCore!

                beforeEach {
                    let commitDirectory = project1.directory("committed").appendingPathComponent(slug1)
                    let file = commitDirectory.appendingPathComponent(file1)

                    if let appDirectory = atlasCore.appDirectory {
                        while FileSystem.fileExists(appDirectory, isDirectory: true) {
                            Helper.deleteBaseDirectory(appDirectory)
                        }
                    } else {
                        expect(false).to(beTrue(), description: "App directory missing")
                    }

                    expect(FileSystem.fileExists(file)).to(beFalse())

                    atlasCore2 = AtlasCore(directory)

                    expect(atlasCore2.initGitAndGitHub(credentials).success).to(beTrue())
                    logEntries += 1
                    expect(
                        atlasCore.completedLogEntries().count
                    ).toEventually(equal(logEntries), timeout: 10)
                }

                it("should reinitialize but not download existing files") {
                    expect(atlasCore2.git?.gitAnnex?.s3Bucket).to(equal(s3Bucket))
                    expect(atlasCore.validRepository()).toEventually(beTrue(), timeout: 10)

                    let commitDirectory = project1.directory("committed").appendingPathComponent(slug1)
                    let file = commitDirectory.appendingPathComponent(file1)
                    expect(FileSystem.fileExists(file)).to(beFalse())
                }

                it("should properly sync with S3 when a new file is added") {
                    Helper.addFile(file4, directory: fileDirectory, contents: file4)

                    let filePath4 = fileDirectory.appendingPathComponent(file4).path
                    expect(project1?.copyInto([filePath4]).success).to(beTrue())
                    expect(atlasCore.commitChanges().success).to(beTrue())

                    logEntries += 1
                    expect(
                        atlasCore.completedLogEntries().count
                    ).toEventually(equal(logEntries), timeout: 10)

                    expect(S3Helper.listObjects(s3Bucket)).toEventually(contain(file4), timeout: 30, description: "\(file4) not found")
                }
            }
        }
    }
}

