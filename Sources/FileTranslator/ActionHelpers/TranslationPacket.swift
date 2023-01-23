// Created 1/13/23
// swift-version:5.0

import Foundation
import JsonModel

let kTemplatePath = "en"

enum FileTypes : String, Codable, CodingKey, CaseIterable {
    case json = "JSON", android = "Android", iOS = "iOS"
    
    func decoder() -> any StringsDecoder {
        switch self {
        case .json:
            return JsonStringsDecoder()
        case .android:
            return AndroidStringsDecoder()
        case .iOS:
            return IOSStringsDecoder()
        }
    }
    
    var fileExtension: String {
        decoder().fileExtension
    }
}

struct TranslationPacket {
    let baseURL: URL
    
    let stringsMap: [FileTypes : [String : StringsContainer]]
    
    init(baseURL: URL, stringsMap: [FileTypes : [String : StringsContainer]]) {
        self.baseURL = baseURL
        self.stringsMap = stringsMap
    }
    
    init(baseURL: URL) throws {
        self.baseURL = baseURL

        let templateURL = baseURL.appending(path: kTemplatePath)
        self.stringsMap = try FileTypes.allCases.reduce(into: [:], { partialResult, fileType in
            partialResult[fileType] = try fileType.decoder().decodeAll(at: templateURL.appending(path: fileType.rawValue))
        })
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
    
    func translateFromHTML() throws {
        let resourceKeys : [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: baseURL,
                                                        includingPropertiesForKeys: resourceKeys,
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .producesRelativePathURLs],
                                                        errorHandler: { (url, error) -> Bool in
            print("directoryEnumerator error at \(url): ", error)
            return true
        })!

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if !resourceValues.isDirectory!, fileURL.pathExtension == "html" {
                try _parseAndTranslate(fileURL: fileURL)
            }
        }
    }
    
    func _parseAndTranslate(fileURL: URL) throws {
        
        let decoder = HTMLTableDecoder()
        let files = try decoder.decode(contentsOf: fileURL)
        
        try files.forEach { fileId, strings in
            let original: StringsContainer = stringsMap[fileId.fileType]?[fileId.filePath].map {
                var ret = $0
                ret.strings.merge(with: strings)
                return ret
            } ?? StringsFile(strings: strings)
            
            let data = try original.encode(for: fileId.fileType)
            let url = baseURL.appending(path: fileId.locale).appending(path: fileId.fileType.rawValue).appending(path: fileId.filePath)
            
            let dirURL = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dirURL.path) {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            try data.write(to: url, options: .atomic)
        }
    }
}

let kWrappedCharacters = CharacterSet(charactersIn: "\n\t\"")

extension String {
    
    func contains(_ characters: CharacterSet) -> Bool {
        self.rangeOfCharacter(from: characters) != nil
    }
    
    func wrapped() -> String {
        var value = self
        value.replace("\\n", with: "\n")
        return value.contains(kWrappedCharacters) ? "\"\(value)\"" : value
    }
}

extension Array where Element == String {
    func tabSeparatedRow() -> String {
        joined(separator: packetRowSeparator) + "\n"
    }
}

fileprivate let packetRowSeparator = "\t"

struct PacketMap : Hashable {
    let rows: [Row]
    
    init(packet: TranslationPacket) throws {
        var rows = [Row]()
        
        let stringsMap = packet.stringsMap
        FileTypes.allCases.forEach { fileType in
            stringsMap[fileType]?.forEach { filepath, container in
                container.strings.forEach { pair in
                    var value = pair.value
                    value.replace("\n", with: "\\n")
                    if fileType == .iOS {
                        value.replace("%@", with: "%1$s")
                    }
                    let idx = rows.firstIndex(where: {
                        $0.english.compare(value, options: .caseInsensitive) == .orderedSame
                    })
                    var row = idx.map { rows[$0] } ?? .init(english: value)
                    row.keys[fileType] = .init(path: filepath, name: pair.name)
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
    
    struct Row : Hashable {
        var keys: [FileTypes: PathNamePair]
        let english: String
        var translation: String?
        var comment: String?
        
        init(english: String) {
            self.keys = [:]
            self.english = english
        }
    }
    
    struct PathNamePair : Hashable {
        let path: String
        let name: String
    }
}
