//
//  GlueSpec.swift
//  AtlasCoreTests
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation
import Quick
import Nimble
import AtlasCore

class GlueSpec: CoreSpec {
    override func spec() {
        describe("Git") {
            
            context("runProcess") {
                
                context("with a simple command") {
                    
                    it("runs the command and returns the result") {
                        let output = Glue.runProcess("git", arguments: ["-c", "ls"])
                        expect(output.range(of: "usage: git")).toNot(
                            beNil(),
                            description: "\(output) should contain 'usage: git'"
                        )
                    }
                }
            }
        }
    }
}
