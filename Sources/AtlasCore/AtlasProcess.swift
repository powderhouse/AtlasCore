//
//  AtlasProcess.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Foundation

public protocol AtlasProcess {
    var currentDirectoryURL: URL? { get set }
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    func runAndWait() -> String
}

public protocol AtlasProcessFactory {
    func build() -> AtlasProcess
}

extension Process: AtlasProcess {
    public func runAndWait() -> String {
        let pipe = Pipe()
        standardOutput = pipe
        
        do {
            try run()
        } catch {
            return "AtlasProcess Error: \(error)"
        }
        waitUntilExit()
        
        let file:FileHandle = pipe.fileHandleForReading
        let data =  file.readDataToEndOfFile()
        return String(data: data, encoding: String.Encoding.utf8) as String!
    }
}

public class ProcessFactory: AtlasProcessFactory {
    public init() {
    }
    
    public func build() -> AtlasProcess {
        return Process()
    }
}

