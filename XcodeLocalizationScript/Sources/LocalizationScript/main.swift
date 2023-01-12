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
func run() {
    
    let arguments = CommandLine.arguments
    var dirpath = (arguments.count <= 1) ? FileManager.default.currentDirectoryPath : arguments[1]
    if dirpath.hasPrefix("~/") {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        dirpath = String(dirpath.replacingOccurrences(of: "~/", with: homeDir.absoluteString))
    }
    guard let url = URL(string: dirpath) else {
        print("Could not create URL from \(dirpath)")
        return
    }
    print("Parsing strings in \(url)")
    
    let finder = StringFinder(url)
    
    do {
        try finder.search()
        try finder.write()
    } catch {
        print(error)
    }
}

struct LocalizedString : Hashable {
    let text: String
    let comment: String
}

class StringFinder {
    let url: URL
    var strings = [String : LocalizedString]()
    let keywords = [
        "Text",
        "Label",
        "NSLocalizedString",
        "Button",
        "LocalizedStringKey",
    ]
    
    init(_ url: URL) {
        self.url = url
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
                    if !textKey.hasPrefix("\\(") {
                        strings[textKey] = .init(text: textKey, comment: line.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
    }
    
    func write(locale: String = "en") throws {
        let dirURL = url
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("\(locale).lproj", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: dirURL.path) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        }
        let fileURL = dirURL
            .appendingPathComponent("Localizable.strings", isDirectory: false)
        
        let data = strings.keys.sorted().compactMap { key in
            guard let value = strings[key] else { return nil }
            return "/* \(value.comment) */\n\"\(key)\" = \"\(value.text)\";\n"
        }.joined(separator: "\n").data(using: .utf8)!
        
        try data.write(to: fileURL, options: .atomic)
    }
}

run()

