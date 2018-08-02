//
//  S3Helper.swift
//  AtlasCorePackageDescription
//
//  Created by Jared Cosulich on 8/1/18.
//

import Cocoa
import AtlasCore

class S3Helper {
    
    static let host = "http://localhost:4572"
    
    class func listBuckets() -> String {
        return Glue.runProcessError("aws", arguments: [
                "--endpoint-url=\(host)",
                "--no-sign-request",
                "s3api",
                "list-buckets"
            ]
        )
    }
    
    class func listObjects(_ bucketName: String) -> String {
        return Glue.runProcessError("aws", arguments: [
            "--endpoint-url=\(host)",
            "--no-sign-request",
            "s3api",
            "list-objects",
            "--bucket=\(bucketName)"
            ]
        )
    }
    
    class func deleteBucket(_ bucketName: String) {
        _ = Glue.runProcessError("aws", arguments: [
                "s3",
                "rb",
                "s3://\(bucketName)",
                "--endpoint-url=\(host)",
                "--no-sign-request",
                "--force"
            ]
        )
    }

}
