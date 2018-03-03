//
//  ProjectSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/26/18.
//


import Foundation
import Quick
import Nimble
import AtlasCore

class ProjectSpec: QuickSpec {
    override func spec() {
        describe("Project") {
            
            var project: Project!
            var directory: URL!
            
            let fileManager = FileManager.default
            var isFile : ObjCBool = false
            var isDirectory : ObjCBool = true
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("testProject")
                project = Project("Project", baseDirectory: directory)                
            }
            
            afterEach {
                FileSystem.deleteDirectory(directory)
            }
            
            context("initialization") {
                
                it("should create subfolders with readmes in them") {
                    for subfolderName in project.states {
                        let folder = project.directory().appendingPathComponent(subfolderName)
                        let exists = fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory)
                        expect(exists).to(beTrue(), description: "No subfolder found for \(subfolderName)")

                        let readme = folder.appendingPathComponent("readme.md")
                        let readmeExists = fileManager.fileExists(atPath: readme.path, isDirectory: &isFile)
                        expect(readmeExists).to(beTrue(), description: "No readme found in \(subfolderName)")
}
                }

            }
            
        }
    }
}
