// Created 1/13/23
// swift-version:5.0

import Foundation

protocol StringsDecoder {
    associatedtype T : StringsContainer
    var fileExtension: String { get }
    func decode(contentsOf fileURL: URL) throws -> T
}

extension StringsDecoder {
    func decodeAll(at url: URL) throws -> [String : T] {
        var result: [String : T] = .init()
        
        let resourceKeys : [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: url,
                                includingPropertiesForKeys: resourceKeys,
                                                   options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                            print("directoryEnumerator error at \(url): ", error)
                                                            return true
        })!

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if !resourceValues.isDirectory!, fileURL.pathExtension == self.fileExtension {
                let relativePath = String(fileURL.absoluteString.dropFirst(url.absoluteString.count + 1))
                let obj = try self.decode(contentsOf: fileURL)
                result[relativePath] = obj
            }
        }
        
        return result
    }
}
