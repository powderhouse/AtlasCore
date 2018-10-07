//
//  AWS.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 10/7/18.
//

import Foundation

public class Iam {

    let accessKeyId: String!
    let secretAccessKey: String!
    
    public init(accessKeyId: String, secretAccessKey: String) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
    
    public func getUser(_ username: String) -> String {
        return Glue.runProcessError("aws", arguments: [
                "iam",
                "atlastestaccount ",
                "--user-name",
                username
            ]
        )
    }
    
}
