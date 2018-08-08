//
//  AtlasProcess.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public protocol AtlasProcess {
    var currentDirectoryURL: URL? { get set }
    var currentDirectoryPath: String { get set }
    var executableURL: URL? { get set }
    var launchPath: String? { get set }
    var arguments: [String]? { get set }
    var environment: [String: String]? { get set }
    func runAndWait() -> String
    func runAndWaitError() -> String
}

public protocol AtlasProcessFactory {
    func build() -> AtlasProcess
}

extension Process: AtlasProcess {
    public func runAndWait() -> String {
        let pipe = Pipe()
        standardOutput = pipe

        launch()
//        do {
//            try run()
//        } catch {
//            return "AtlasProcess Error: \(error)"
//        }
//        waitUntilExit()
        
        let file:FileHandle = pipe.fileHandleForReading
        let data =  file.readDataToEndOfFile()
        if let result = String(data: data, encoding: String.Encoding.utf8) {
            return result
        }
        return ""
    }
    
    public func runAndWaitError() -> String {
        let pipe = Pipe()
        standardOutput = pipe
        standardError = pipe
    
        launch()
        //        do {
        //            try run()
        //        } catch {
        //            return "AtlasProcess Error: \(error)"
        //        }
        //        waitUntilExit()
    
        let file:FileHandle = pipe.fileHandleForReading
        let data =  file.readDataToEndOfFile()
        if let result = String(data: data, encoding: String.Encoding.utf8) as String? {
            return result
        } else {
            return "ERROR"
        }
    }
}

public class ProcessFactory: AtlasProcessFactory {
    public init() {
    }
    
    public func build() -> AtlasProcess {
        return Process()
    }
}

