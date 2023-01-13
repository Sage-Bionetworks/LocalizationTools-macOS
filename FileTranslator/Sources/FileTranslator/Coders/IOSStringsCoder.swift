// Created 1/12/23
// swift-version:5.0

import Foundation
import RegexBuilder

struct IOSStringsEncoder {
    func encode(_ value: StringsFile) throws -> Data {
        value.strings.map { $0.xcodeString() }.joined(separator: "\n").data(using: .utf8)!
    }
}

extension StringsFile.StringValue {
    fileprivate func xcodeString() -> String {
        """
        /* \(comment ?? "") */
        "\(name.isEmpty ? value : name)" = "\(value)";
        
        """
    }
}

struct IOSStringsDecoder {
    func decode(contentsOf fileURL: URL) throws -> StringsFile {
        let data = try Data(contentsOf: fileURL)
        let decodedString = String(data: data, encoding: .utf8)!
        let stringPairs = decodedString.matches(of: #/".*" ?= ?".*";/#)
        let comments = decodedString.matches(of: #/\/\* .* \*\//#)
        
        let stringPairRegex = Regex {
            "\""
            Capture(OneOrMore(.any))
            "\""
            ZeroOrMore(.whitespace)
            "="
            ZeroOrMore(.whitespace)
            "\""
            Capture(OneOrMore(.any))
            "\";"
        }
        
        var previousEnd: String.Index?
        let strings: [StringsFile.StringValue] = try stringPairs.enumerated().map { offset, pair in
            let comment: String? = comments.first { match in
                match.endIndex < pair.startIndex && (previousEnd.map { $0 < match.startIndex } ?? true)
            }.map { match in
                String(match.output.dropFirst(3).dropLast(3))
            }
            guard let parts = pair.output.firstMatch(of: stringPairRegex)?.output
            else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Could not parse \(pair.output)"))
            }
            let name = String(parts.1)
            let value = String(parts.2)

            previousEnd = pair.endIndex
            return .init(name: name, value: value, comment: comment)
        }
        
        return .init(strings: strings)
    }
}
