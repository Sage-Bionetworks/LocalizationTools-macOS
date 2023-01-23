// Created 1/12/23
// swift-version:5.0

import Foundation
import XMLCoder

class AndroidStringsEncoder : XMLEncoder {
    
    override init() {
        super.init()
        self.charactersEscapedInElements = [
            ("&", "&amp;"),
            ("<", "&lt;"),
            ("'", "&apos;"),
            ("\"", "&quot;"),
        ]
    }
    
    func encode(strings value: StringsFile) throws -> Data {
        let encodedData = try self.encode(value, withRootKey: "resources", header: XMLHeader(version: 1.0, encoding: "UTF-8"))
        let encodedString = String(data: encodedData, encoding: .utf8)!
        let data = encodedString
            .replacing("UTF-8", with: "utf-8")
            .replacing("<string", with: "\n    <string")
            .replacing("</resources>", with: "\n</resources>\n")
            .data(using: .utf8)!
        return data
    }
}

class AndroidStringsDecoder : XMLDecoder, StringsDecoder {
    init() {
        super.init(trimValueWhitespaces: false, removeWhitespaceElements: false)
    }
    
    var fileExtension: String { "xml" }
    
    func decode(contentsOf fileURL: URL) throws -> StringsFile {
        let data = try Data(contentsOf: fileURL)
        return try self.decode(StringsFile.self, from: data)
    }
}
