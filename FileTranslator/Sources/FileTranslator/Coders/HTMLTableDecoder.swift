// Created 1/18/23
// swift-version:5.0

import Foundation
import XMLCoder

let kNoTranslation = "NO TRANSLATION FOUND"

class HTMLTableDecoder : XMLDecoder {
    init() {
        super.init(removeWhitespaceElements: false)
    }
    
    func decode(contentsOf fileURL: URL) throws -> [FileIdentifier : [StringValue]] {
    
        var html = try String(contentsOf: fileURL)
        // remove bits around the table.
        if let lower = html.firstRange(of: "<table")?.lowerBound,
           let upper = html.firstRange(of: "</table>")?.upperBound {
            html = String(html[lower..<upper])
        }
        // convert <br> to "\\n"
        html.replace("<br>", with: "\\n")
        let data = html.data(using: .utf8)!
        
        let table = try self.decode(HtmlTable.self, from: data)
        
        guard let headerRow = table.tbody.tr.first?.td,
              let englishIdx = headerRow.firstIndex(of: "English"),
              let translationIdx = headerRow.firstIndex(of: "Translation"),
              let commentIdx = headerRow.firstIndex(of: "Comments")
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Table does not include header row"))
        }
        
        let localeCode = fileURL.deletingPathExtension().lastPathComponent
        let keyIndexes: [(Int, FileTypes)] = try Array(0..<englishIdx).filter({ $0 % 2 == 0 }).map { idx in
            guard let rawValue = headerRow[idx].components(separatedBy: " ").first,
                  let fileType = FileTypes(rawValue: rawValue)
            else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Table headers do not contain expected KeyValuePairs: \(headerRow)"))
            }
            return (idx, fileType)
        }

        var result = [FileIdentifier : [StringValue]]()
        
        try table.tbody.tr.dropFirst().forEach { row in
            guard row.td.count > commentIdx else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Table row does not include expected columns. \(row.td)"))
            }
            
            let english = row.td[englishIdx]
            let translation = row.td[translationIdx]
            let comment = row.td[commentIdx]

            guard !english.isEmpty else { return }
            
            keyIndexes.forEach { idx, fileType in
                let path = row.td[idx]
                var name = row.td[idx + 1]
                if name.isEmpty && fileType == .iOS {
                    name = english.replacing("%1$s", with: "%@")
                }
                guard !name.isEmpty && !path.isEmpty else { return }
                
                [kTemplatePath, localeCode].forEach { locale in
                    var value = (locale == localeCode) ? translation : english
                    if value.isEmpty {
                        value = kNoTranslation
                    }
                    if fileType == .iOS {
                        value.replace("%1$s", with: "%@")
                    }
                    let fileId = FileIdentifier(filePath: path, fileType: fileType, locale: locale)
                    var strings = result[fileId] ?? []
                    strings.append(.init(name: name, value: value, comment: comment))
                    result[fileId] = strings
                }
            }
        }

        return result
    }
    
    struct HtmlTable : Codable {
        let tbody: TableBody
        
        struct TableBody : Codable {
            let tr: [TableRow]
        }
        
        struct TableRow : Codable {
            let td: [String]
        }
    }
}

struct FileIdentifier : Hashable {
    let filePath: String
    let fileType: FileTypes
    let locale: String
}

