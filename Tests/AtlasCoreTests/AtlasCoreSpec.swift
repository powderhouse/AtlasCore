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

            it("should pass") {
                expect(true).to(beTrue())
            }
            
            it("should execute a process") {
                
                let p = Process()
                
                let pipe = Pipe()
                p.standardOutput = pipe

                print("")
                print("")
                print("")
                print("")
                print("")
                print("PROCESS: \(p)")
                let m = Mirror(reflecting: p)
                print("M: \(m)")
                for (name, value) in m.children {
                    print("\(name): \(type(of: value)) = '\(value)'")
                }

                if let m2 = m.superclassMirror {
                    print("M2: \(m2)")
                    for (name, value) in m2.children {
                        print("\(name): \(type(of: value)) = '\(value)'")
                    }
                }
                print("STANDARD OUT: \(p.standardOutput)")
                print("")
                print("")
                print("")
                print("")
                print("")
                print("")

                p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                p.arguments = ["pwd"]
                
                do {
                    try p.run()
                } catch {
                    print("AtlasProcess Error: \(error)")
                }
                
                p.waitUntilExit()
                
                let file:FileHandle = pipe.fileHandleForReading
                let data = file.readDataToEndOfFile()
                expect(String(data: data, encoding: String.Encoding.utf8)).to(contain("/tmp"))
            }
        }
    }
}

