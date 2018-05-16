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

//    let kSearchMax = 1000
//    func search(_ queryText: String) {
//        var options: SKSearchOptions = kSKSearchOptionDefault
////        if searchOptionNoRelevance != 0 {
////            options |= kSKSearchOptionNoRelevanceScores
////        }
////        if searchOptionSpaceIsOR != 0 {
////            options |= kSKSearchOptionSpaceMeansOR
////        }
////        if searchOptionSpaceFindSimilar != 0 {
////            options |= kSKSearchOptionFindSimilar
////        }
//
//        let query = NSString(string: queryText)
//        var search = SKSearchCreate(skIndex, query, options).takeRetainedValue()
//
//        //..........................................................................
//        // get matches from a search object
//        var more = true
//        var totalCount: UInt32 = 0
//        while more {
//            var foundDocIDs = [SKDocumentID](repeating: SKDocumentID(), count: kSearchMax)
//            var foundScores = [Float](repeating: 0.0, count: kSearchMax)
//            var foundDocRefs = [SKDocument?](repeating: nil, count: kSearchMax)
//            var scores = [Float]()
////            var unranked = Bool(options & kSKSearchOptionNoRelevanceScores)
////            if unranked {
////                scores = nil
////            } else {
////                scores = foundScores
////            }
//            scores = foundScores
//
//            var foundCount = CFIndex(0)
//            var pos: CFIndex = 0
//            more = SKSearchFindMatches(search, kSearchMax, foundDocIDs, scores, 1, foundCount)
//            totalCount += foundCount
//
//            SSKIndexCopyDocumentRefsForDocumentIDs(mySKIndex as? SKIndex?, CFIndex(foundCount), foundDocIDs as? SKDocumentID, foundDocRefs as? SKDocument?)
//
//
//            for pos in 0..<foundCount {
//                var doc = foundDocRefs[pos] as? SKDocument?
//                var url = SKDocumentCopyURL(doc)
//                var urlStr = url.absoluteString
//                var desc = ""
//                if unranked {
//                desc = "---\nDocID: \(Int(foundDocIDs[pos])), URL: \(urlStr)"
//                } else {
//                desc = "---\nDocID: \(Int(foundDocIDs[pos])), Score: \(foundScores[pos]), URL: \(urlStr)"
//                }
//                log(desc)
//            }
//
//            var desc = "\"\(query)\" - \(Int(totalCount)) matches"
//            log(desc)
//        }
    
    
    
    public func search(_ terms: String) -> [NSURL] {
        let stopwords: Set = ["all", "and", "its", "it's", "the"]

//        let properties: [NSObject: AnyObject] = [
////            NSString("kSKStartTermChars"): "", // additional starting-characters for terms
////            NSString("kSKTermChars"): "-_@.'", // additional characters within terms
////            NSString("kSKEndTermChars"): "",   // additional ending-characters for terms
//            NSString("kSKMinTermLength"): 3,
//            NSString("kSKStopWords"): stopwords
//        ]

        let query = NSString(string: terms)
        let options = SKSearchOptions(kSKSearchOptionDefault)
        let search = SKSearchCreate(skIndex, query, options).takeUnretainedValue()

        let limit = 10               // Maximum number of results
        let time: TimeInterval = 1 // Maximum time to get results, in seconds

        var documentIDs: [SKDocumentID] = Array(repeating: 0, count: limit)
        var urls: [Unmanaged<CFURL>?] = Array(repeating: nil, count: limit)
        var scores: [Float] = Array(repeating: 0, count: limit)
        var count: CFIndex = 0

        let hasMoreResults = SKSearchFindMatches(search, limit, &documentIDs, &scores, time, &count)

        SKIndexCopyDocumentURLsForDocumentIDs(skIndex, count, &documentIDs, &urls)

        let results: [NSURL] = zip(urls[0 ..< count], scores).flatMap({
            (cfurl, score) -> NSURL? in
            guard let url = cfurl?.takeUnretainedValue() as NSURL?
                else { return nil }

            return url
        })

        return results
    }
    
    public func close() {
        SKIndexClose(self.skIndex)
        self.skIndex = nil
    }
    
}
