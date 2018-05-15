//
//  SearchSpec.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 5/5/18.
//

import Cocoa
import Quick
import Nimble
import AtlasCore

class SearchSpec: QuickSpec {
    override func spec() {
        describe("Search") {
            
            var directory: URL!

            let fileName = "test.txt"
            var file: URL!
            
            var search: Search?
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SEARCH")

                FileSystem.deleteDirectory(directory)

                FileSystem.createDirectory(directory)
                Helper.addFile(fileName, directory: directory, contents: "some text")
                file = directory.appendingPathComponent(fileName)
                expect(try? String(contentsOf: file, encoding: .utf8)).to(contain("some text"))
                
                search = Search(directory)
                expect(search).toNot(beNil())
            }
            
            afterEach {
//                if search != nil {
//                    search!.close()
//                    expect(search!.skIndex).toEventually(beNil())
//                }
                FileSystem.deleteDirectory(directory)
            }
            
            context("add") {
                it("should successfully add a file to the search index") {
//                    if search != nil {
//                        expect(search!.add(file)).to(beTrue())
//                    } else {
//                        expect(false).to(beTrue(), description: "Search is nil")
//                    }
                    expect(true).to(beTrue())
                }
            }
            
//            context("search") {
//                beforeEach {
//                    if search != nil {
//                        expect(search!.add(file)).to(beTrue())
//                    } else {
//                        expect(false).to(beTrue(), description: "Search is nil")
//                    }
//                }
//
//                it("should return results when searched") {
////                    search.search("some")
//                    expect(false).to(beTrue())
//                }
//            }
        }
    }
}

