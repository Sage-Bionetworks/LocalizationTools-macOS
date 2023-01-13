import XCTest
@testable import FileTranslator

final class FileTranslatorTests: XCTestCase {
    
    func testAndroidStringsFile_Decoding() throws {
        guard let fileURL = Bundle.module.url(forResource: "strings", withExtension: "xml")
        else {
            XCTFail("Failed to get strings file")
            return
        }
        
        let decoder = AndroidStringsDecoder()
        let resources = try decoder.decode(contentsOf: fileURL)
        
        let expectedFirst = StringsFile.StringValue(name: "app_name", value: "Mobile Toolbox")
        XCTAssertEqual(expectedFirst, resources.strings.first)
        
        let expectedToWithdraw = StringsFile.StringValue(name: "to_withdraw", value: "To <b>withdraw from this study</b>, you’ll need the following info:")
        let actualToWithdraw = resources.strings.first(where: { $0.name == expectedToWithdraw.name })
        XCTAssertEqual(expectedToWithdraw, actualToWithdraw)
    }
    
    func testAndroidXMLStringsFile_Encoding() throws {
        let file = StringsFile(strings: [
            .init(name: "app_name", value: "Mobile Toolbox"),
            .init(name: "to_withdraw", value: "To <b>withdraw from this study</b>, you’ll need the following info:"),
        ])
        
        let encoder = AndroidStringsEncoder()
        let data = try encoder.encode(file)
        let actualValue = String(data: data, encoding: .utf8)!
        
        let expectedValue = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<resources>\r\n    <string name=\"app_name\">Mobile Toolbox</string>\r\n    <string name=\"to_withdraw\">To &lt;b>withdraw from this study&lt;/b>, you’ll need the following info:</string>\r\n</resources>"
        
        XCTAssertEqual(expectedValue, actualValue)
    }
    
    func testIOSStringsFile_Decoding() throws {
        guard let fileURL = Bundle.module.url(forResource: "Localizable", withExtension: "strings")
        else {
            XCTFail("Failed to get strings file")
            return
        }
        
        let decoder = IOSStringsDecoder()
        let strings = try decoder.decode(contentsOf: fileURL).strings
        
        let expectedFirst = StringsFile.StringValue(name: "ABOUT THE STUDY", value: "ABOUT THE STUDY",
                                                    comment: "return Text(\"ABOUT THE STUDY\", bundle: .module)")
        XCTAssertEqual(expectedFirst.name, strings.first?.name)
        XCTAssertEqual(expectedFirst.value, strings.first?.value)
        XCTAssertEqual(expectedFirst.comment, strings.first?.comment)
    }
    
}
