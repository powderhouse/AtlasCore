//
//  Search.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 5/5/18.
//

import Cocoa

public class Search {
    
    var directory: URL!
    var indexURL: NSURL!
    public weak var skIndex: SKIndex!
    let indexName = NSString(string: "SearchIndex")
    
    public init?(_ directory: URL) {
        self.directory = directory
        self.indexURL = NSURL(fileURLWithPath: directory.appendingPathComponent("search.index").path)
        
        let type: SKIndexType = kSKIndexInverted
        
        skIndex = SKIndexOpenWithURL(self.indexURL, self.indexName, true)?.takeUnretainedValue()
        
        if skIndex == nil {
            skIndex = SKIndexCreateWithURL(
                self.indexURL,
                self.indexName,
                type,
                nil
            )?.takeUnretainedValue()
        }

        guard skIndex != nil else { return nil }

        SKLoadDefaultExtractorPlugIns()
    }
    
    public func add(_ file: URL) -> Bool {
        let nsFile = NSURL(fileURLWithPath: file.path)
        let doc = SKDocumentCreateWithURL(nsFile)
        
        let success = SKIndexAddDocument(
            skIndex,
            doc?.takeUnretainedValue(),
            nil,
            true
        )
        
        if success {
            return SKIndexFlush(self.skIndex)
        }
        
        return false
    }
    
    
    public func search(_ terms: String) -> [NSURL] {
        let query = NSString(string: terms)
        let options = SKSearchOptions(kSKSearchOptionDefault)
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
            
            let results: [NSURL] = zip(urls[0 ..< count], scores).flatMap({
                (cfurl, score) -> NSURL? in
                guard let url = cfurl?.takeUnretainedValue() as NSURL?
                    else { return nil }
                
                return url
            })
            allResults += results
        }

        return allResults
    }
    
    public func close() {
        SKIndexClose(self.skIndex)
        self.skIndex = nil
    }
    
}
