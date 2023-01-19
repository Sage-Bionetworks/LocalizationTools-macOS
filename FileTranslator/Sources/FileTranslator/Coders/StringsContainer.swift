// Created 1/12/23
// swift-version:5.0

import Foundation
import XMLCoder
import JsonModel

protocol StringsContainer {
    var strings: [StringValue] { get }
}

struct StringValue: Codable, Hashable, DynamicNodeEncoding {
    let name: String
    let value: String
    var comment: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case value = ""
    }
    
    static func nodeEncoding(for key: CodingKey) -> XMLCoder.XMLEncoder.NodeEncoding {
        switch key {
        case CodingKeys.name:
            return .attribute
        default:
            return .element
        }
    }
}

struct StringsFile: Codable, Hashable, StringsContainer {
    let strings: [StringValue]
    
    enum CodingKeys: String, CodingKey {
        case strings = "string"
    }
}

struct JsonFile : Codable, Hashable, StringsContainer {
    private(set) var json: AnyCodableDictionary
    var strings: [StringValue]

    init(from decoder: Decoder) throws {
        let json = try AnyCodableDictionary(from: decoder)
        self.json = json
        self.strings = json.dictionary.flattenLocalizedStrings()
    }
    
    func encode(to encoder: Encoder) throws {
        try json.encode(to: encoder)
    }
}

// Add to this as we come across more keys. syoung 01/13/2022
fileprivate let localizedKeys = [
    "title",
    "detail",
    "text",
]

fileprivate let separatorKey = "|"

extension Dictionary where Key == String, Value == JsonSerializable {
    func flattenLocalizedStrings(_ path: String = "") -> [StringValue] {
        reduce(into: []) { partialResult, element in
            let levelKey = "\(path)\(element.key)"
            if let array = element.value as? [Dictionary<String, JsonSerializable>] {
                partialResult.append(contentsOf: array.flattenLocalizedStrings("\(levelKey)\(separatorKey)"))
            }
            else if let dictionary = element.value as? [String : JsonSerializable] {
                partialResult.append(contentsOf: dictionary.flattenLocalizedStrings("\(levelKey)\(separatorKey)"))
            }
            else if let str = element.value as? String, localizedKeys.contains(element.key) {
                partialResult.append(.init(name: "\(levelKey)", value: str))
            }
        }
    }
}

extension Array where Element == Dictionary<String, JsonSerializable> {
    func flattenLocalizedStrings(_ path: String) -> [StringValue] {
        enumerated().flatMap { offset, element in
            element.flattenLocalizedStrings("\(path)\(offset)\(separatorKey)")
        }
    }
}
