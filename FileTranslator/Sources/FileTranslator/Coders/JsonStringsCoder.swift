// Created 1/13/23
// swift-version:5.0

import Foundation
import JsonModel

class JsonStringsEncoder : OrderedJSONEncoder {
}

class JsonStringsDecoder : JSONDecoder, StringsDecoder {
    
    var fileExtension: String { "json" }
    
    func decode(contentsOf fileURL: URL) throws -> JsonFile {
        let data = try Data(contentsOf: fileURL)
        return try self.decode(JsonFile.self, from: data)
    }
}
