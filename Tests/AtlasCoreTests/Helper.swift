//
//  Helper.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 2/13/18.
//

import Cocoa
import AtlasCore

class Helper {
    
    class func addFile(_ name: String, directory: URL) {
        let filePath = "\(directory.path)/\(name)"
        _ = Glue.runProcess("touch", arguments: [filePath])
    }
    
}
