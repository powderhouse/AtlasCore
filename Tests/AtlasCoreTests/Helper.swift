//
//  Helper.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Cocoa
import AtlasCore

class Helper {
    
    class func addFile(_ name: String, directory: URL, contents: String="") {
        let filePath = "\(directory.path)/\(name)"
        let url = URL(fileURLWithPath: filePath)
        
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return
        }
    }
    
}
