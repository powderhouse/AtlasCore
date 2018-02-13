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
            
            let atlasCore = AtlasCore()

            context("getDefaultBaseDirectory") {
                it("should provide the Application Support folder") {
                    let path = atlasCore.getDefaultBaseDirectory().path
                    expect(path).to(contain("Application Support"))
                }
            }
        }
    }
}

