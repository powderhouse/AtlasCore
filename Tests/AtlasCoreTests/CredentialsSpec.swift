//
//  CredentialsSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/14/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class CredentialsSpec: QuickSpec {
    override func spec() {
        describe("Credentials") {
            
            var credentials: Credentials!
            
            let username = "atlastest"
            let password = "1a2b3c4d"
            let token = "TOKEN"
            let remotePath = "REMOTE_PATH"

            var directory: URL!
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true

            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testCredentials")
                
                Helper.createBaseDirectory(directory)
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
            }
            
            afterEach {
                Helper.deleteBaseDirectory(directory)
            }
            
            context("with token") {
                
                beforeEach {
                    credentials = Credentials(username, password: password, token: token)
                }
                
                it("should initialize properly") {
                    expect(credentials.username).to(equal(username))
                    expect(credentials.password).to(equal(password))
                    expect(credentials.token).to(equal(token))
                }
                
                context("save") {
                    beforeEach {
                        credentials.save(directory)
                    }
                    
                    it("should write the credentials to a file in the specified directory") {
                        let filePath = "\(directory.path)/credentials.json"
                        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "No credentials json found")
                    }
                }
                
            }
            
            context("without token") {
                beforeEach {
                    credentials = Credentials(username, password: password)
                }

                it("should initialize properly") {
                    expect(credentials.username).to(equal(username))
                    expect(credentials.password).to(equal(password))
                    expect(credentials.token).to(beNil())
                }
                
                context("save") {
                    beforeEach {
                        credentials.save(directory)
                    }
                    
                    it("should not write the credentials to a file in the specified directory because the token is missing") {
                        let filePath = "\(directory.path)/credentials.json"
                        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                        expect(exists).toNot(beTrue(), description: "Credentials json found but should not be")
                    }
                }
                
                context("with remote path") {
                    beforeEach {
                        credentials = Credentials(username, remotePath: remotePath)
                    }
                    
                    it("should initialize properly") {
                        expect(credentials.username).to(equal(username))
                        expect(credentials.password).to(beNil())
                        expect(credentials.token).to(beNil())
                        expect(credentials.remotePath).to(equal(remotePath))
                    }
                    
                    context("save") {
                        beforeEach {
                            credentials.save(directory)
                        }
                        
                        it("should not write the credentials to a file in the specified directory because the token is missing") {
                            let filePath = "\(directory.path)/credentials.json"
                            let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                            expect(exists).to(beTrue(), description: "Credentials json not found")
                        }
                    }
                }

            }
            
            context("retrieve") {
                
                var credentials: Credentials?
                
                beforeEach {
                    Credentials(username, token: token).save(directory)
                    credentials = Credentials.retrieve(directory).first
                }
                
                it("should retrieve and instantiate the saved credentials") {
                    expect(credentials).toNot(beNil())
                    expect(credentials?.username).to(equal(username))
                    expect(credentials?.token).to(equal(token))
                }
            }
            
            context("delete") {
                var filePath: String!

                beforeEach {
                    Credentials(username, token: token).save(directory)

                    filePath = "\(directory.path)/credentials.json"
                    let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "No credentials json found")
                }
                
                it("should delete the credentials file") {
                    _ = Credentials.delete(directory)
                    
                    let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                    expect(exists).to(beFalse(), description: "credentials json still exists")
                }
            }
            
            context("complete") {
                let s3AccessKey = "S3ACCESSKEY"
                let s3SecretAccessKey = "S3SECRETACCESSKEY"

                it("should be complete if user, token, and s3 access keys are presnt") {
                    credentials = Credentials(
                        username,
                        token: token,
                        s3AccessKey: s3AccessKey,
                        s3SecretAccessKey: s3SecretAccessKey
                    )
                    expect(credentials.complete()).to(beTrue())
                }
                
                it("should be complete if user, password, and s3 access keys are presnt") {
                    credentials = Credentials(
                        username,
                        password: password,
                        s3AccessKey: s3AccessKey,
                        s3SecretAccessKey: s3SecretAccessKey
                    )
                    expect(credentials.complete()).to(beTrue())
                }
                
                it("should not be complete if s3 access keys are missing") {
                    credentials = Credentials(
                        username,
                        password: password
                    )
                    expect(credentials.complete()).to(beFalse())

                }
                
            }
            
        }
    }
}
