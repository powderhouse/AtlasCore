//
//  S3Helper.swift
//  AtlasCorePackageDescription
//
//  Created by Jared Cosulich on 8/1/18.
//

import Cocoa
import AtlasCore

class S3Helper {
    
    class func listBuckets() -> String {
        let a = Glue.runProcessError("aws", arguments: [
                "--endpoint-url=http://localhost:4572",
                "--no-sign-request",
                "s3api",
                "list-buckets"
            ]
        )
        return a
    }
    
    class func deleteBucket(_ bucketName: String) {
        _ = Glue.runProcessError("aws", arguments: [
                "s3",
                "rb",
                "s3://\(bucketName)",
                "--endpoint-url=http://localhost:4572",
                "--no-sign-request",
                "--force"
            ]
        )
    }

}
