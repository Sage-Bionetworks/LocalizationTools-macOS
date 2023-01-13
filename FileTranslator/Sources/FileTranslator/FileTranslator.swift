@main
public struct FileTranslator {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(FileTranslator().text)
    }
}
