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

            var directory: URL!
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true

            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testCredentials")
                
                FileSystem.createDirectory(directory)
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
            }
            
            afterEach {
                FileSystem.deleteDirectory(directory)
            }
            
            context("with token") {
                
                let token = "TOKEN"
                
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
            }
            
        }
    }
}
