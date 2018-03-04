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
    func getKeysAndTypes(forObject:Any?) -> Dictionary<String,String> {
        var answer:Dictionary<String,String> = [:]
        var counts = UInt32();
        let properties = class_copyPropertyList(object_getClass(forObject), &counts);
        for i in 0..<counts {
            let property = properties?.advanced(by: Int(i)).pointee;
            
            let cName = property_getName(property!);
            let name = String(cString: cName)
            
            let cAttr = property_getAttributes(property!)!
            let attr = String(cString:cAttr).components(separatedBy: ",")[0].replacingOccurrences(of: "T", with: "");
            answer[name] = attr;
            //print("ID: \(property.unsafelyUnwrapped.debugDescription): Name \(name), Attr: \(attr)")
        }
        return answer;
    }
    
    override func spec() {
        
        describe("AtlasCore") {

            it("should pass") {
                expect(true).to(beTrue())
            }
            
            it("should execute a process") {
                
                let p = Process()
                
                let pipe = Pipe()
                p.standardOutput = pipe

                p.arguments = ["pwd"]

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
                print("ARGS: \(p.arguments)")

                var count: UInt32 = 0
                let properties = class_copyPropertyList(object_getClass(p), &count)
                print("PROPERTIES: \(properties)")
                
                if properties != nil {
                    for index in 0...count {
                        let property1 = property_getName(properties![Int(index)])
                        let result1 = String(cString: property1)
                        print(result1)
                    }
                }
                
                print("KEYS: \(self.getKeysAndTypes(forObject: p))")
                print("LAUNCH PATH: \(p.launchPath)")
                print("")
                print("")
                p.launchPath = "/usr/bin/env"
                print("LAUNCH PATH: \(p.launchPath)")
                print("")
                print("")
                print("")
                print("")

//                p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                
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

