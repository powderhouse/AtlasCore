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
            let credentials = Credentials(
                "atlastest",
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
                FileSystem.deleteDirectory(directory)
            }


            context("getDefaultBaseDirectory") {
                it("should provide the Application Support folder") {
                    let path = atlasCore.getDefaultBaseDirectory().path
                    expect(path).to(contain("Application Support"))
                }
            }
            
            context("initGit") {
                beforeEach {
                    _ = atlasCore.initGit(credentials)
                }
                
                it("saves the credentials to the filesystem") {
                    let credentialsFile = atlasCore.baseDirectory.appendingPathComponent("github.json")
                    let exists = fileManager.fileExists(atPath: credentialsFile.path, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "No github.json found")
                }

                it("saves the credentials to the filesystem") {
                    let readmeFile = atlasCore.baseDirectory.appendingPathComponent("readme.md")
                    let exists = fileManager.fileExists(atPath: readmeFile.path, isDirectory: &isFile)
                    expect(exists).to(beTrue(), description: "No readme.md found")
                }
}
        }
    }
}

