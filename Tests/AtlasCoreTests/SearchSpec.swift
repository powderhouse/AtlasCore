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

            let fileName1 = "test1.txt"
            var file1: URL!

            let fileName2 = "test2.txt"
            var file2: URL!

            var search: Search?
            
            beforeEach {
                directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SEARCH")

                FileSystem.deleteDirectory(directory)

                FileSystem.createDirectory(directory)
                
                Helper.addFile(fileName, directory: directory, contents: "some text one can search")
                file = directory.appendingPathComponent(fileName)
                expect(try? String(contentsOf: file, encoding: .utf8)).to(contain("some text"))

                Helper.addFile(fileName1, directory: directory, contents: "more text another might search")
                file1 = directory.appendingPathComponent(fileName1)
                expect(try? String(contentsOf: file1, encoding: .utf8)).to(contain("more text"))

                Helper.addFile(fileName2, directory: directory, contents: "even more text another might search")
                file2 = directory.appendingPathComponent(fileName2)
                expect(try? String(contentsOf: file2, encoding: .utf8)).to(contain("even more text"))

                search = Search(directory)
                expect(search).toNot(beNil())
            }
            
            afterEach {
                if search != nil {
                    search!.close()
                    expect(search!.skIndex).toEventually(beNil())
                }
                FileSystem.deleteDirectory(directory)
            }
            
            context("add") {
                it("should successfully add a file to the search index") {
                    if search != nil {
                        expect(search!.add(file)).to(beTrue())
                        expect(search!.add(file1)).to(beTrue())
                        expect(search!.add(file2)).to(beTrue())
                        let docCount = SKIndexGetDocumentCount(search?.skIndex).distance(to: 0) * -1
                        expect(docCount).toEventually(equal(9))
                    } else {
                        expect(false).to(beTrue(), description: "Search is nil")
                    }
                }
            }
            
            context("search") {
                beforeEach {
                    if search != nil {
                        expect(search!.add(file)).to(beTrue())
                        expect(search!.add(file1)).to(beTrue())
                        expect(search!.add(file2)).to(beTrue())
                    } else {
                        expect(false).to(beTrue(), description: "Search is nil")
                    }
                }

//                it("should return results when searching name of file") {
//                    if search != nil {
//                        let results = search!.search("test1")
//                        expect(results.count).toEventually(equal(1))
//                    } else {
//                        expect(false).to(beTrue(), description: "Search is nil")
//                    }
//                }

                it("should return results when searching contents of file") {
                    if search != nil {
                        let results = search!.search("more")
                        expect(results.count).toEventually(equal(2))
                    } else {
                        expect(false).to(beTrue(), description: "Search is nil")
                    }
                }
            }
        }
    }
}

