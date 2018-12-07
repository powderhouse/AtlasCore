//
//  Search.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 5/5/18.
//

import Cocoa

public class Search {
    
    public static let indexFileName = "search.index"
    
    var directory: URL!
    var indexURL: NSURL!
    public weak var skIndex: SKIndex!
    var indexFileName: String!
    let indexName = NSString(string: "SearchIndex")
    
    var files: [URL] = []
    
    public class func exists(_ directory: URL) -> Bool {
        let indexURL = directory.appendingPathComponent(Search.indexFileName)
        return FileSystem.fileExists(indexURL)
    }
    
    public init?(_ directory: URL, indexFileName: String?=Search.indexFileName) {
        self.directory = directory
        self.indexFileName = indexFileName
        self.indexURL = NSURL(fileURLWithPath: directory.appendingPathComponent(self.indexFileName).path)
        
        let type: SKIndexType = kSKIndexInverted
        
        if Search.exists(directory) {
            skIndex = SKIndexOpenWithURL(self.indexURL, self.indexName, true)?.takeUnretainedValue()
        }
        
        if skIndex == nil {
            let options: CFDictionary = [
                kSKMinTermLength: 1
            ] as CFDictionary
            
            skIndex = SKIndexCreateWithURL(
                self.indexURL,
                self.indexName,
                type,
                options
            )?.takeUnretainedValue()
        }

        guard skIndex != nil else { return nil }

        SKLoadDefaultExtractorPlugIns()
    }
    
    public func add(_ file: URL) -> Bool {
        files.append(file)
        
        let nsFile = NSURL(fileURLWithPath: file.path)
        let doc = SKDocumentCreateWithURL(nsFile)
        
        var mimeType: NSString? = nil
        if file.lastPathComponent.contains(".md") {
            mimeType = NSString(string: "text/plain")
        } elsif file.lastPathComponent.contains(".xlsx") {
            return false
        }
        
        let success = SKIndexAddDocument(
            skIndex,
            doc?.takeUnretainedValue(),
            mimeType,
            true
        )
        
        if success {
            return SKIndexFlush(self.skIndex)
        }
        
        return false
    }
    
    public func move(from: URL, to: URL) -> Bool {
        let success = add(to)

//        let fromDoc = SKDocumentCreateWithURL(NSURL(fileURLWithPath: from.path))
//
//        var toDoc = SKDocumentCreateWithURL(NSURL(fileURLWithPath: to.path))
//        if from.lastPathComponent == to.lastPathComponent {
//            let toDirectory = to.deletingLastPathComponent()
//            toDoc = SKDocumentCreateWithURL(NSURL(fileURLWithPath: toDirectory.path))
//        }
//
//        let success = SKIndexMoveDocument(
//            self.skIndex,
//            fromDoc?.takeUnretainedValue(),
//            toDoc?.takeUnretainedValue()
//        )
        
        if success {
            return remove(from)            
        }
        
        return false
    }
    
    public func remove(_ file: URL) -> Bool {
        let document = SKDocumentCreateWithURL(NSURL(fileURLWithPath: file.path))
        return SKIndexRemoveDocument(self.skIndex, document?.takeUnretainedValue())
    }
    
    public func search(_ terms: String) -> [NSURL] {
        guard SKIndexFlush(self.skIndex) else { return [] }
        
        let query = NSString(string: terms)
        let options: SKSearchOptions = SKSearchOptions(kSKSearchOptionSpaceMeansOR)

        let search = SKSearchCreate(skIndex, query, options).takeUnretainedValue()

        let limit = 10
        let time: TimeInterval = 1

        var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
        var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
        var scores: [Float] = Array(repeating: 0, count: limit)
        var count: CFIndex = 0

        var hasMoreResults = true
        var allResults: [NSURL] = []
        while hasMoreResults {
            hasMoreResults = SKSearchFindMatches(search, limit, &documentIDs, &scores, time, &count)
            
            SKIndexCopyDocumentURLsForDocumentIDs(skIndex, count, &documentIDs, &urls)
            
            let results: [NSURL] = zip(urls[0 ..< count], scores).compactMap({
                (cfurl, score) -> NSURL? in
                guard let url = cfurl?.takeUnretainedValue() as NSURL?
                    else { return nil }
                
                return url
            })
            allResults += results
        }
        
        for file in files {
            let fileName = file.lastPathComponent.lowercased()
            if fileName != Project.readme && fileName.contains(terms.lowercased()) {
                allResults.append(NSURL(fileURLWithPath: file.path))
            }
        }

        return allResults
    }
    
    public func documentCount() -> Int {
        return SKIndexGetDocumentCount(self.skIndex).distance(to: 0) * -1
    }
    
    public func close() {
        SKIndexClose(self.skIndex)
        self.skIndex = nil
    }
    
}
