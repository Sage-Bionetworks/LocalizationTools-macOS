// Created 1/14/23
// swift-version:5.0

import Foundation

let html = ["b","u"]

struct FileCleaner {
    func clean(at url: URL) throws {
        let resourceKeys : [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: url,
                                includingPropertiesForKeys: resourceKeys,
                                                   options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                            print("directoryEnumerator error at \(url): ", error)
                                                            return true
        })!

        let fileExtensions = FileTypes.allCases.reduce(into: [String : FileTypes]()) { partialResult, fileType in
            partialResult[fileType.fileExtension] = fileType
        }
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if !resourceValues.isDirectory!, let fileType = fileExtensions[fileURL.pathExtension] {
                let ogValue = try String(contentsOf: fileURL)
                var value = ogValue
                value.clean(for: fileType)
                if value != ogValue {
                    try value.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            }
        }
    }
}

extension String {
    mutating func clean(for fileType: FileTypes) {
        // If XML file (Android) then need to replace the "<" of html with "&lt;" or the XML coding doesn't work.
        if fileType == .android {
            html.forEach { charCode in
                self.replace("<\(charCode)>", with: "&lt;\(charCode)>")
                self.replace("</\(charCode)>", with: "&lt;/\(charCode)>")
            }
        }
        // In all cases, replace the ' with ’ which doesn't have to be escaped on Android and keeps usage in
        // places like "you’re" consistent.
        self.replace(#/\\'/#, with: "’")
        self.replace(#/\'/#, with: "’")
    }
}


