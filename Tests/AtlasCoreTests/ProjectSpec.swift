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
            
            context("commitSlug") {
                it("should provide a slug from the message") {
                    let slug = project.commitSlug("A commit message.")
                    expect(slug).to(equal("a-commit-message"))
                }
                
                it("should handle a long complicated message by truncating to 254 characters") {
                    let message = "A really-really-really long and complicated message! Just so bl@#~ping complicated*** What will the slug be? I'm really not too sure, but we'll see: \"Boo Yaa\"! Now let's do it again: A really-really-really long and complicated message! Just so bl@#~ping complicated*** What will the slug be? I'm really not too sure, but we'll see: \"Boo Yaa\"!"
                    let slug = project.commitSlug(message)
                    expect(slug).to(equal("a-really-really-really-long-and-complicated-message-just-so-bl-ping-complicated-what-will-the-slug-be-i-m-really-not-too-sure-but-we-ll-see-boo-yaa-now-let-s-do-it-again-a-really-really-really-long-and-complicated-message-just-so-bl-ping-complicated-what"))
                }
            }
            
        }
    }
}
