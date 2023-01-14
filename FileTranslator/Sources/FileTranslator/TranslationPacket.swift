// Created 1/13/23
// swift-version:5.0

import Foundation
import JsonModel

fileprivate let templatePath = "en"

enum FileTypes : String, Codable, CodingKey, CaseIterable {
    case json = "JSON", android = "Android", iOS = "iOS"
}

struct TranslationPacket : Hashable {
    let baseURL: URL
    
    let android: [String : StringsFile]
    let iOS: [String : StringsFile]
    let json: [String : JsonFile]
    
    var stringsMap: [FileTypes : [String : StringsContainer]] {
        [
            .android : android,
            .iOS : iOS,
            .json : json
        ]
    }
    
    init(baseURL: URL) throws {
        self.baseURL = baseURL
        
        let templateURL = baseURL.appending(path: templatePath)
        
        let androidDecoder = AndroidStringsDecoder()
        self.android = try androidDecoder.decodeAll(at: templateURL.appending(path: FileTypes.android.rawValue))
        
        let iosDecoder = IOSStringsDecoder()
        self.iOS = try iosDecoder.decodeAll(at: templateURL.appending(path: FileTypes.iOS.rawValue))
        
        let jsonDecoder = JsonStringsDecoder()
        self.json = try jsonDecoder.decodeAll(at: templateURL.appending(path: FileTypes.json.rawValue))
    }
    
    func exportToTSV() throws {
        // TODO: syoung 01/13/2022 Read existing file and update rather than overwrite to keep existing translations.
        
        let packet = try PacketMap(packet: self)
        let fileURL = baseURL.appendingPathComponent("TranslationPacket.tsv", isDirectory: false)
        
        var headerStringValues = FileTypes.allCases.flatMap { fileType in
            ["\(fileType.rawValue) path", "\(fileType.rawValue) name"]
        }
        headerStringValues.append("English")
        headerStringValues.append("Translation")
        headerStringValues.append("Comment")

        let data = packet.rows.reduce(into: headerStringValues.tabSeparatedRow()) { partialResult, row in
            var rowValues = FileTypes.allCases.flatMap { fileType in
                [row.keys[fileType]?.path ?? "", row.keys[fileType]?.name.wrapped() ?? ""]
            }
            rowValues.append(row.english.wrapped())
            rowValues.append(row.translation?.wrapped() ?? "")
            rowValues.append(row.comment?.wrapped() ?? "")
            partialResult += rowValues.tabSeparatedRow()
        }.data(using: .utf8, allowLossyConversion: true)!

        try data.write(to: fileURL, options: .atomic)
    }
}

extension String {
    func wrapped() -> String {
        self.contains("\n") ? "\"\(self)\"" : self
    }
}

extension Array where Element == String {
    func tabSeparatedRow() -> String {
        joined(separator: packetRowSeparator) + "\n"
    }
}

fileprivate let packetRowSeparator = "\t"

struct PacketMap : Hashable, Codable {
    let rows: [Row]
    
    init(packet: TranslationPacket) throws {
        var rows = [Row]()
        
        let stringsMap = packet.stringsMap
        FileTypes.allCases.forEach { fileType in
            stringsMap[fileType]?.forEach { filepath, container in
                container.strings.forEach { pair in
                    var value = pair.value
                    if fileType == .android {
                        // Clean up apostrophes in android string
                        value.replace("\'", with: "’")
                    }
                    
                    let idx = rows.firstIndex(where: { $0.english == pair.value })
                    var row = idx.map { rows[$0] } ?? .init(english: pair.value)
                    let name = pair.name == pair.value ? "" : pair.name
                    row.keys[fileType] = .init(path: filepath, name: name)
                    if let comment = pair.comment {
                        row.comment = comment
                    }
                    if let idx = idx {
                        rows[idx] = row
                    }
                    else {
                        rows.append(row)
                    }
                }
            }
        }
        
        self.rows = rows
    }
    
    struct Row : Hashable, Codable {
        var keys: [FileTypes: PathNamePair]
        let english: String
        var translation: String?
        var comment: String?
        
        init(english: String) {
            self.keys = [:]
            self.english = english
        }
    }
    
    struct PathNamePair : Hashable, Codable {
        let path: String
        let name: String
    }
}
