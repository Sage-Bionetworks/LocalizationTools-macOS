//
//  Copyright © 2021 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

// TODO: syoung 10/26/2021 Parse the string files and use existing translations from those files.

/// This is a script that can be used to build "Localizable.strings" files by searching the swift files in the package and looking for
/// SwiftUI/Localizable elements. While Xcode is suppose to have a script that does this, it doesn't work with Swift PM (only apps)
/// because of course it doesn't. - syoung 10/26/2021
class XcodeStringFinder {
    let url: URL
    let locale: String
    let stringsFile: URL
    
    var strings = [StringValue]()
    
    let keywords = [
        "Text",
        "Label",
        "NSLocalizedString",
        "Button",
        "LocalizedStringKey",
    ]
    
    init(_ url: URL, locale: String = "en") {
        self.url = url
        self.locale = locale
        
        let fileURL = url
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("\(locale).lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings", isDirectory: false)
        
        self.stringsFile = fileURL
        
        let decoder = IOSStringsDecoder()
        guard let decodedValues = try? decoder.decode(contentsOf: fileURL)
        else {
            self.strings = []
            return
        }
        
        self.strings = decodedValues.strings
    }
    
    func searchAndReplace() throws {
        try search()
        try write()
    }
    
    func search() throws {
        let resourceKeys : [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: url,
                                includingPropertiesForKeys: resourceKeys,
                                                   options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                            print("directoryEnumerator error at \(url): ", error)
                                                            return true
        })!

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if !resourceValues.isDirectory!, fileURL.pathExtension == "swift", !fileURL.pathComponents.contains("Resources") {
                try parse(fileURL: fileURL)
            }
        }
    }
    
    func parse(fileURL: URL) throws {
        guard fileURL.pathExtension == "swift" else { return }
        let currentCode = try String(contentsOf:fileURL, encoding: String.Encoding.utf8)
        let lines = currentCode.components(separatedBy: .newlines)
        lines.forEach { line in
            keywords.forEach { keyword in
                let searchWord = "\(keyword)(\""
                if let range = line.range(of: searchWord),
                   let endIdx = line[range.upperBound...].firstIndex(of: "\"") {
                    let textKey = String(line[range.upperBound..<endIdx])
                    if !textKey.hasPrefix("\\("), !self.strings.contains(where: { $0.name == textKey }) {
                        var value = textKey
                        value.clean(for: .iOS)
                        self.strings.append(.init(name: textKey, value: value, comment: line.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                }
            }
        }
    }
    
    func write() throws {
        // create directory
        let dirURL = stringsFile.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dirURL.path) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // encode strings
        let encoder = IOSStringsEncoder()
        let container = StringsFile(strings: strings)
        let data = try encoder.encode(strings: container)
        try data.write(to: stringsFile, options: .atomic)
    }
}

