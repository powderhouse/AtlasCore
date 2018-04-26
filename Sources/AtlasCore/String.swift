//
//  String.swift
//  AtlasCore
//
//  Created by Jared Cosulich on 4/25/18.
//

extension String {
    var unescaped: String {
        let entities = ["\\", "\"", "\'"]
        var current = self
        for entity in entities {
            let descriptionCharacters = entity.debugDescription.dropFirst().dropLast()
            let description = String(descriptionCharacters)
            current = current.replacingOccurrences(of: description, with: entity)
        }
        return current
    }
}

