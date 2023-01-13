// Created 1/12/23
// swift-version:5.0

import Foundation
import XMLCoder

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

struct StringsFile: Codable, Hashable {
    let strings: [StringValue]
    
    enum CodingKeys: String, CodingKey {
        case strings = "string"
    }
}

