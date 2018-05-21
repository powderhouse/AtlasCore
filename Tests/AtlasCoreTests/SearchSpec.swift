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

                search = Search(directory, indexFileName: "search\(NSDate().timeIntervalSince1970).index")
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
                beforeEach {
                    if search != nil {
                        expect(search!.add(file)).to(beTrue())
                        expect(search!.add(file1)).to(beTrue())
                        expect(search!.add(file2)).to(beTrue())
                    } else {
                        expect(false).to(beTrue(), description: "Search is nil")
                    }
                }

                it("should successfully add a file to the search index") {
                    expect(search?.documentCount()).toEventually(equal(9))
                }
            }
            
            context("with files added") {
                beforeEach {
                    if search != nil {
                        expect(search!.add(file)).to(beTrue())
                        expect(search!.add(file1)).to(beTrue())
                        expect(search!.add(file2)).to(beTrue())
                    } else {
                        expect(false).to(beTrue(), description: "Search is nil")
                    }
                }
                
                context("move") {

                    it("should return the new file path") {
                        print("START DOC COUNT: \(search?.documentCount())")
                        
                        var newFile2 = file2.deletingLastPathComponent()
                        let newDir = newFile2.appendingPathComponent("NEWDIR")
                        newFile2 = newDir.appendingPathComponent(fileName2)

                        FileSystem.createDirectory(newDir)
                        expect(FileSystem.move(file2.path, into: newDir)).to(beTrue())

                        if search != nil {
                            expect(search!.move(from: file2, to: newFile2)).to(beTrue())

                            let results = search!.search("even more text")
                            expect(results.count).toEventually(equal(1))

                            let iterator = SKIndexDocumentIteratorCreate(search?.skIndex, nil).takeUnretainedValue()
                            var document = SKIndexDocumentIteratorCopyNext(iterator)

                            print("")
                            print("")
                            print("")
                            print("DOC COUNT: \(search?.documentCount())")
                            print("")
                            while document != nil {
                                var parent = document?.takeRetainedValue()
                                while parent != nil {
                                    let docURL = SKDocumentCopyURL(parent).takeRetainedValue()
                                    print("DOC: \(docURL)")
                                    print("")
                                    parent = SKDocumentGetParent(parent)?.takeRetainedValue()
                                    print("")
                                    print("PARENT: \(parent)")
                                }
                                document = SKIndexDocumentIteratorCopyNext(iterator)
                            }
                            print("")
                            print("")
                            print("")

                            expect(results.first?.path).to(contain("NEWDIR"))
                        } else {
                            expect(false).to(beTrue(), description: "Search is nil")
                        }
                    }
                }
                
                context("remove") {
                    it("should remove the file from the index") {
                        if search != nil {
                            let searchText = "even more text"
                            expect(search?.documentCount()).to(equal(9))
                            expect(search!.search(searchText).count).toEventually(equal(1))

                            expect(search?.remove(file2)).to(beTrue())
                            expect(search?.documentCount()).to(equal(8))
                            expect(search!.search(searchText).count).toEventually(equal(0))
                        } else {
                            expect(false).to(beTrue(), description: "Search is nil")
                        }
                    }
                }
            
                context("search") {
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
}

