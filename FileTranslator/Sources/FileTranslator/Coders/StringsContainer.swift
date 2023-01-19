// Created 1/12/23
// swift-version:5.0

import Foundation
import XMLCoder
import JsonModel

protocol StringsContainer {
    var strings: [StringValue] { get set }
    
    func encode(for fileType: FileTypes) throws -> Data
}

struct StringValue: Codable, Hashable, DynamicNodeEncoding {
    let name: String
    var value: String
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
    var strings: [StringValue]
    
    enum CodingKeys: String, CodingKey {
        case strings = "string"
    }
    
    func encode(for fileType: FileTypes) throws -> Data {
        switch fileType {
        case .android:
            let encoder = AndroidStringsEncoder()
            return try encoder.encode(strings: self)
        case .iOS:
            let encoder = IOSStringsEncoder()
            return try encoder.encode(strings: self)
        default:
            throw EncodingError.invalidValue(fileType, .init(codingPath: [], debugDescription: "Cannot encode a \(fileType) from this object."))
        }
    }
}

struct JsonFile : Codable, Hashable, StringsContainer {
    private let json: AnyCodableDictionary
    var strings: [StringValue]

    init(from decoder: Decoder) throws {
        let json = try AnyCodableDictionary(from: decoder)
        self.json = json
        self.strings = json.dictionary.flattenLocalizedStrings()
    }
    
    func encode(to encoder: Encoder) throws {
        var dictionary = json.dictionary
        strings.forEach { stringValue in
            let keyPath = stringValue.name.components(separatedBy: separatorKey)
            dictionary.replace(at: keyPath, with: stringValue.value)
        }
        let encodable = AnyCodableDictionary(dictionary, orderedKeys: Array(json.orderedDictionary.keys))
        try encodable.encode(to: encoder)
    }
    
    func encode(for fileType: FileTypes) throws -> Data {
        guard fileType == .json else {
            throw EncodingError.invalidValue(fileType, .init(codingPath: [], debugDescription: "Cannot encode a \(fileType) from this object."))
        }
        let encoder = JsonStringsEncoder()
        return try encoder.encode(self)
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
    
    mutating func replace(at path: [String], with value: String) {
        guard let foundKey = path.first, let obj = self[foundKey]
        else {
            return
        }
        if let array = obj as? [Dictionary<String, JsonSerializable>] {
            var newArray = array
            newArray.replace(at: Array<String>(path.dropFirst()), with: value)
            self[foundKey] = newArray as [JsonSerializable]
        }
        else if let dictionary = obj as? [String : JsonSerializable] {
            var newDictionary = dictionary
            newDictionary.replace(at: Array<String>(path.dropFirst()), with: value)
            self[foundKey] = newDictionary
        }
        else if obj is String {
            self[foundKey] = value.replacing("\\n", with: "\n")
        }
    }
}

extension Array where Element == Dictionary<String, JsonSerializable> {
    func flattenLocalizedStrings(_ path: String) -> [StringValue] {
        enumerated().flatMap { offset, element in
            element.flattenLocalizedStrings("\(path)\(offset)\(separatorKey)")
        }
    }
    
    mutating func replace(at path: [String], with value: String) {
        guard let foundIdx = path.first.flatMap({ Int($0) }), foundIdx < self.count, path.count >= 2
        else {
            return
        }
        var dictionary = self[foundIdx]
        dictionary.replace(at: Array<String>(path.dropFirst()), with: value)
        self[foundIdx] = dictionary
    }
}

extension Array where Element == StringValue {
    
    /// Merge the translation strings into the original list.
    mutating func merge(with other: [StringValue]) {
        var translation = other
        let newValues = self.map { thisValue in
            guard let foundIdx = translation.firstIndex(where: { $0.name == thisValue.name })
            else {
                return thisValue
            }
            var stringValue = translation.remove(at: foundIdx)
            if stringValue.comment?.isEmpty ?? true, let comment = thisValue.comment {
                stringValue.comment = comment
            }
            return stringValue
        }
    
        self = newValues + translation.map {
            var ret = $0
            ret.value = kNoTranslation
            return ret
        }
    }
}

