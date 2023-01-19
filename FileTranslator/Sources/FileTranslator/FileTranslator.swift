import Foundation

@main
public struct FileTranslator {
    enum Actions : String, CaseIterable {
        case create, clean, translate
    }

    public static func main() {
        let arguments = CommandLine.arguments
        var argIdx = 1
        
        guard arguments.count >= argIdx + 1, let action = Actions(rawValue: arguments[argIdx])
        else {
            print("What do you want to do? \(Actions.allCases)")
            return
        }
        argIdx += 1
        
        var dirpath = (arguments.count <= argIdx) ? FileManager.default.currentDirectoryPath : arguments[argIdx]
        if dirpath.hasPrefix("~/") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            dirpath = String(dirpath.replacingOccurrences(of: "~/", with: homeDir.absoluteString))
        }
        guard let url = URL(string: dirpath) else {
            print("Could not create URL from \(dirpath)")
            return
        }
        
        do {
            switch action {
            case .create:
                print("creating translation packet at \(url)")
                let packet = try TranslationPacket(baseURL: url)
                try packet.exportToTSV()
            case .clean:
                let templateURL = url.appending(path: kTemplatePath)
                let cleaner = FileCleaner()
                print("cleaning strings at \(templateURL)")
                try cleaner.clean(at: templateURL)
            case .translate:
                print("translating at \(url)")
                let packet = try TranslationPacket(baseURL: url)
                try packet.translateFromHTML("es")
            }
        }
        catch {
            print("Failed to \(action) translation packet: \(error)")
        }
    }
}
