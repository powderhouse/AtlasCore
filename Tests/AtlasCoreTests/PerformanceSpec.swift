//
//  PerformanceSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 4/10/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

struct PerformanceCapture {
    public var name: String
    public var duration: TimeInterval
}

class PerformanceCoreSpec: QuickSpec {
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
            
            var performance: [PerformanceCapture] = []
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ATLAS_CORE")
                
                FileSystem.createDirectory(directory)
                
                let filePath = directory.path
                let exists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                expect(exists).to(beTrue(), description: "No folder found")
                
                
                var time = Date().timeIntervalSince1970
                atlasCore = AtlasCore(directory)
                performance.append(PerformanceCapture(
                    name: "Init AtlasCore",
                    duration: Date().timeIntervalSince1970 - time
                ))

                time = Date().timeIntervalSince1970
                _ = atlasCore.initGitAndGitHub(credentials)
                performance.append(PerformanceCapture(
                    name: "Init GitHub",
                    duration: Date().timeIntervalSince1970 - time
                ))
            }
            
            afterEach {
                atlasCore.deleteGitHubRepository()
                FileSystem.deleteDirectory(directory)

                print("""




TIMES:

\(performance.map{ "\($0.name): \($0.duration)" }.joined(separator: "\n"))




""")
            }
            
            it("should execute and record times") {
                let fileDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FILE_DIR")
                FileSystem.createDirectory(fileDirectory)
                Helper.addFile("index.html", directory: fileDirectory)
                
                var time = Date().timeIntervalSince1970
                expect(atlasCore.initProject("Project")).to(beTrue())
                performance.append(PerformanceCapture(
                    name: "Init Project",
                    duration: Date().timeIntervalSince1970 - time
                ))
                
                time = Date().timeIntervalSince1970
                let project = atlasCore.project("Project")
                performance.append(PerformanceCapture(
                    name: "Find Project",
                    duration: Date().timeIntervalSince1970 - time
                ))
                
                let filePath = fileDirectory.appendingPathComponent("index.html").path
                
                time = Date().timeIntervalSince1970
                expect(project?.copyInto([filePath])).to(beTrue())
                performance.append(PerformanceCapture(
                    name: "Import Into Project",
                    duration: Date().timeIntervalSince1970 - time
                ))

                time = Date().timeIntervalSince1970
                atlasCore.atlasCommit()
                performance.append(PerformanceCapture(
                    name: "Atlas Commit",
                    duration: Date().timeIntervalSince1970 - time
                ))
                
                time = Date().timeIntervalSince1970
                expect(project!.commitMessage("A commit message")).to(beTrue())
                performance.append(PerformanceCapture(
                    name: "Setting Commit Message",
                    duration: Date().timeIntervalSince1970 - time
                ))

                time = Date().timeIntervalSince1970
                expect(project!.commitStaged()).to(beTrue())
                performance.append(PerformanceCapture(
                    name: "Commit Staged",
                    duration: Date().timeIntervalSince1970 - time
                ))
                
                time = Date().timeIntervalSince1970
                atlasCore.commitChanges("A commit message")
                performance.append(PerformanceCapture(
                    name: "Push To GitHub",
                    duration: Date().timeIntervalSince1970 - time
                ))
                
                expect(performance.count).to(beGreaterThan(0))
            }
            
            
        }
    }
}
