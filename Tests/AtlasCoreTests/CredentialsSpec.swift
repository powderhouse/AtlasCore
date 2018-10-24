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

class CredentialsSpec: CoreSpec {
    override func spec() {
        describe("Credentials") {
            
            var credentials: Credentials!
            
            let username = "atlastest"
            let email = "atlastest@puzzleschool.com"
            let token = "TOKEN"
            let s3AccessKey = "S3ACCESSKEY"
            let s3SecretAccessKey = "S3SECRETACCESSKEY"
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
                    credentials = Credentials(
                        username,
                        email: email,
                        password: self.githubPassword,
                        token: token,
                        s3AccessKey: s3AccessKey,
                        s3SecretAccessKey: s3SecretAccessKey,
                        directory: directory
                    )
                }
                
                it("should initialize properly") {
                    expect(credentials.username).to(equal(username))
                    expect(credentials.password).to(equal(self.githubPassword))
                    expect(credentials.token).to(equal(token))
                    expect(credentials.s3AccessKey).to(equal(s3AccessKey))
                    expect(credentials.s3SecretAccessKey).to(equal(s3SecretAccessKey))
                }
                
                context("save") {
                    beforeEach {
                        credentials.save()
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
                    credentials = Credentials(
                        username,
                        email: email,
                        password: self.githubPassword,
                        directory: directory
                    )
                }

                it("should initialize properly") {
                    expect(credentials.username).to(equal(username))
                    expect(credentials.password).to(equal(self.githubPassword))
                    expect(credentials.token).to(beNil())
                }
                
                context("save") {
                    beforeEach {
                        credentials.save()
                    }
                    
                    it("should write the credentials to a file even though the token is missing") {
                        let filePath = "\(directory.path)/credentials.json"
                        let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isFile)
                        expect(exists).to(beTrue(), description: "Credentials json not found ")
                    }
                }
                
                context("with remote path") {
                    beforeEach {
                        credentials = Credentials(
                            username,
                            email: email,
                            remotePath: remotePath,
                            directory: directory
                        )
                    }
                    
                    it("should initialize properly") {
                        expect(credentials.username).to(equal(username))
                        expect(credentials.password).to(beNil())
                        expect(credentials.token).to(beNil())
                        expect(credentials.remotePath).to(equal(remotePath))
                    }
                    
                    context("save") {
                        beforeEach {
                            credentials.save()
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
                
                let authenticationError = "Failed to authenticate."
                
                beforeEach {
                    Credentials(
                        username,
                        email: email,
                        token: token,
                        s3AccessKey: s3AccessKey,
                        s3SecretAccessKey: s3SecretAccessKey,
                        authenticationError: authenticationError,
                        directory: directory
                    ).save()
                    credentials = Credentials.retrieve(directory).first
                }
                
                it("should retrieve and instantiate the saved credentials") {
                    expect(credentials).toNot(beNil())
                    expect(credentials?.username).to(equal(username))
                    expect(credentials?.token).to(equal(token))
                    expect(credentials?.s3AccessKey).to(equal(s3AccessKey))
                    expect(credentials?.s3SecretAccessKey).to(equal(s3SecretAccessKey))
                    expect(credentials?.authenticationError).to(equal(authenticationError))
                    expect(credentials?.token).to(equal(token))
                }
            }
            
            context("delete") {
                var filePath: String!

                beforeEach {
                    Credentials(username, email: email, token: token, directory: directory).save()

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
                        email: email,
                        token: token,
                        s3AccessKey: s3AccessKey,
                        s3SecretAccessKey: s3SecretAccessKey,
                        directory: directory
                    )
                    expect(credentials.complete()).to(beTrue())
                }
                
                it("should be complete if user, password, and s3 access keys are presnt") {
                    credentials = Credentials(
                        username,
                        email: email,
                        password: self.githubPassword,
                        s3AccessKey: s3AccessKey,
                        s3SecretAccessKey: s3SecretAccessKey,
                        directory: directory
                    )
                    expect(credentials.complete()).to(beTrue())
                }
                
                it("should not be complete if s3 access keys are missing") {
                    credentials = Credentials(
                        username,
                        email: email,
                        password: self.githubPassword,
                        directory: directory
                    )
                    expect(credentials.complete()).to(beFalse())

                }
                
            }
            
        }
    }
}
