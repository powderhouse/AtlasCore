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

