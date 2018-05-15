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
            ).takeUnretainedValue()
        }

        guard skIndex != nil else { return nil }

        SKLoadDefaultExtractorPlugIns()
    }
    
    public func add(_ file: URL) -> Bool {
        let nsFile = NSURL(fileURLWithPath: file.path)
        let doc = SKDocumentCreateWithURL(nsFile)
        
        return SKIndexAddDocument(
            skIndex,
            doc?.takeRetainedValue(),
            nil,
            true
        )
    }

    public func search(_ terms: String) {
        let stopwords: Set = ["all", "and", "its", "it's", "the"]
        
//        let properties: [NSObject: AnyObject] = [
////            NSString("kSKStartTermChars"): "", // additional starting-characters for terms
////            NSString("kSKTermChars"): "-_@.'", // additional characters within terms
////            NSString("kSKEndTermChars"): "",   // additional ending-characters for terms
//            NSString("kSKMinTermLength"): 3,
//            NSString("kSKStopWords"): stopwords
//        ]
//
//        let index = SKIndexCreateWithURL(nsUrl, nil, SKIndexType(kSKIndexInverted.rawValue), properties).takeRetainedValue()
        
        let query = NSString(string: terms)
        let options = SKSearchOptions(kSKSearchOptionDefault)
        let search = SKSearchCreate(skIndex, query, options).takeRetainedValue()
        
        let limit = 10               // Maximum number of results
        let time: TimeInterval = 10 // Maximum time to get results, in seconds
        
        var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
        var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
        var scores: [Float] = Array(repeating: 0, count: limit)
        var count: CFIndex = 0
        
        let hasMoreResults = SKSearchFindMatches(search, limit, &documentIDs, &scores, time, &count)
        
        SKIndexCopyDocumentURLsForDocumentIDs(skIndex, count, &documentIDs, &urls)
        
        let results: [NSURL] = zip(urls[0 ..< count], scores).flatMap({
            (cfurl, score) -> NSURL? in
            guard let url = cfurl?.takeRetainedValue() as NSURL?
                else { return nil }
            
            print("- \(url): \(score)")
            return url
        })

        print("RESULTS: \(results) - \(hasMoreResults)")
    }
    
    public func close() {
        SKIndexClose(self.skIndex)
    }
    
}
