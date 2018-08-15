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

class AtlasCoreAnnexSpec: QuickSpec {
    override func spec() {
        
        describe("AtlasCoreAnnex") {
            
            var atlasCore: AtlasCore!
            
            var directory: URL!
            
            let username = "atlastest"
            let credentials = Credentials(
                username,
                s3AccessKey: "test",
                s3SecretAccessKey: "test"
            )
            
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
                Helper.createBaseDirectory(directory)
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
                
                atlasCore = AtlasCore(directory)
                
                expect(atlasCore.initGitAndGitHub(credentials)).toNot(beNil())

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
            
            afterEach {
                logEntries = 0
                while FileSystem.fileExists(directory, isDirectory: true) {
                    Helper.deleteBaseDirectory(directory)
                }
                if let s3Bucket = atlasCore.git?.gitAnnex?.s3Bucket {
                    S3Helper.deleteBucket(s3Bucket)
                }
            }
            
            it("should sync with s3, reflecting files and directory structures") {
                let objects = S3Helper.listObjects(s3Bucket)

                for identifier in [slug1, slug2, file1, file2, file3] {
                    expect(objects).toEventually(contain(identifier), timeout: 10, description: "\(identifier) not found")
                }
            }

            context("purging files and projects") {

                it("should remove the file from S3 when purged") {

                    let relativePath = "\(project2.name!)/committed/\(slug2)/\(file2)"

                    expect(atlasCore.purge([relativePath]).success).to(beTrue())

                    expect(S3Helper.listObjects(s3Bucket)).toEventuallyNot(contain(file2), timeout: 10)

                    let objects = S3Helper.listObjects(s3Bucket)

                    for identifier in [slug1, slug2, file1, file3] {
                        expect(objects).to(contain(identifier), description: "\(identifier) not found")
                    }
                }

                it("should remove project and all files from S3 when the project is deleted") {
                    let path = project2.directory().path
                    expect(atlasCore.purge([path]).success).to(beTrue())

                    for identifier in [slug2, file2, file3] {
                        expect(S3Helper.listObjects(s3Bucket)).toEventuallyNot(contain(identifier), timeout: 10, description: "\(identifier) still found")

                    }

                    let objects = S3Helper.listObjects(s3Bucket)

                    for identifier in [slug1, file1] {
                        expect(objects).to(contain(identifier), description: "\(identifier) not found")
                    }
                }
            }
        }
    }
}

