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
        
        let expectedFirst = StringValue(name: "app_name", value: "Mobile Toolbox")
        XCTAssertEqual(expectedFirst, resources.strings.first)
        
        let expectedToWithdraw = StringValue(name: "to_withdraw", value: "To <b>withdraw from this study</b>, you’ll need the following info:")
        let actualToWithdraw = resources.strings.first(where: { $0.name == expectedToWithdraw.name })
        XCTAssertEqual(expectedToWithdraw, actualToWithdraw)
    }
    
    func testAndroidStringsFile_Encoding() throws {
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
        
        let expectedFirst = StringValue(name: "ABOUT THE STUDY", value: "ABOUT THE STUDY",
                                        comment: "return Text(\"ABOUT THE STUDY\", bundle: .module)")
        XCTAssertEqual(expectedFirst.name, strings.first?.name)
        XCTAssertEqual(expectedFirst.value, strings.first?.value)
        XCTAssertEqual(expectedFirst.comment, strings.first?.comment)
    }
    
    func testIOSStringsFile_Encoding() throws {
        let file = StringsFile(strings: [
            .init(name: "app_name", value: "Mobile Toolbox"),
            .init(name: "to_withdraw", value: "To <b>withdraw from this study</b>, you’ll need the following info:"),
        ])
        
        let encoder = IOSStringsEncoder()
        let data = try encoder.encode(file)
        let actualValue = String(data: data, encoding: .utf8)!
        
        let expectedValue = """
        /*  */
        "app_name" = "Mobile Toolbox";
        
        /*  */
        "to_withdraw" = "To <b>withdraw from this study</b>, you’ll need the following info:";
        
        """
        
        XCTAssertEqual(expectedValue, actualValue)
    }
    
    func testJsonFile_Coding() throws {
        guard let fileURL = Bundle.module.url(forResource: "PrivacyNotice", withExtension: "json")
        else {
            XCTFail("Failed to get strings file")
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let actualValue = try decoder.decode(JsonFile.self, from: data)
        
        XCTAssertEqual("notices|0|text", actualValue.strings.first?.name)
        XCTAssertEqual("Collect the data you give us when you register and when you use the App. This may include sensitive data like your health information.", actualValue.strings.first?.value)
        
        let encoder = JSONEncoder()
        
        let encodedData = try encoder.encode(actualValue)
        
        let expectedDictionary = try! JSONSerialization.jsonObject(with: data) as! NSDictionary
        let actualDictionary = try JSONSerialization.jsonObject(with: encodedData) as? NSDictionary
        XCTAssertEqual(expectedDictionary, actualDictionary)
    }
    
    func testAndroidEscapedApostrophe() throws {
        guard let fileURL = Bundle.module.url(forResource: "strings", withExtension: "xml")
        else {
            XCTFail("Failed to get strings file")
            return
        }
        
        let decoder = AndroidStringsDecoder()
        let stringsFile = try decoder.decode(contentsOf: fileURL)
        let translationPacket = TranslationPacket(baseURL: fileURL.deletingLastPathComponent(),
                                                  stringsMap: [.android : [fileURL.lastPathComponent : stringsFile]])
        let rows = try PacketMap(packet: translationPacket).rows
        
        guard let actualRow = rows.first(where: { $0.keys[.android]?.name == "please_dont_close" })
        else {
            XCTFail("Failed to find expected row")
            return
        }
        
        XCTAssertEqual("Please don’t close the app quite yet, we’re uploading your contributions to the cloud.", actualRow.english)
        
    }
    
    func testHtmlTable_Decode() throws {
        guard let fileURL = Bundle.module.url(forResource: "es", withExtension: "html")
        else {
            XCTFail("Failed to get html file")
            return
        }
        
        let decoder = HTMLTableDecoder()
        let table = try decoder.decode(contentsOf: fileURL)
//
//        XCTAssertEqual(174, table.tbody.tr.count)
//        let headerRow = ["JSON path","JSON name","Android path","Android name","iOS path","iOS name","English","Translation","Comments",""]
//        XCTAssertEqual(headerRow, table.tbody.tr.first?.td)
    }
}
