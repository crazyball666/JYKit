import XCTest
@testable import JYKit

// MARK: - UserDefaults

final class UserDefaultsManagerTests: XCTestCase {
    private var createdKeys: [String] = []

    override func tearDown() {
        createdKeys.forEach { UserDefaultsManager.delete(key: $0) }
        createdKeys.removeAll()
        super.tearDown()
    }

    private func makeKey(_ name: String) -> String {
        let key = "JYKitTests.\(name).\(UUID().uuidString)"
        createdKeys.append(key)
        return key
    }

    private func storedValue(for key: String) -> Any? {
        return UserDefaultsManager.suite.object(forKey: key)
    }

    func testStringRoundTrip() {
        let key = makeKey("string")
        let result = UserDefaultsManager.save(key: key, value: "hello", type: .string)
        XCTAssertTrue(result.success, result.message)
        XCTAssertEqual(storedValue(for: key) as? String, "hello")
    }

    func testBoolRoundTrip() {
        let key = makeKey("bool")
        XCTAssertTrue(UserDefaultsManager.save(key: key, value: true, type: .bool).success)
        XCTAssertEqual((storedValue(for: key) as? NSNumber)?.boolValue, true)

        XCTAssertTrue(UserDefaultsManager.save(key: key, value: "false", type: .bool).success)
        XCTAssertEqual((storedValue(for: key) as? NSNumber)?.boolValue, false)
    }

    func testIntRoundTrip() {
        let key = makeKey("int")
        XCTAssertTrue(UserDefaultsManager.save(key: key, value: "42", type: .int).success)
        XCTAssertEqual((storedValue(for: key) as? NSNumber)?.intValue, 42)
    }

    func testDoubleRoundTrip() {
        let key = makeKey("double")
        XCTAssertTrue(UserDefaultsManager.save(key: key, value: 3.14, type: .double).success)
        XCTAssertEqual((storedValue(for: key) as? NSNumber)?.doubleValue ?? 0, 3.14, accuracy: 0.0001)
    }

    func testJSONRoundTrip() {
        let key = makeKey("json")
        let json = "{\"name\":\"jykit\",\"enabled\":true}"
        XCTAssertTrue(UserDefaultsManager.save(key: key, value: json, type: .json).success)

        let dictionary = storedValue(for: key) as? [String: Any]
        XCTAssertEqual(dictionary?["name"] as? String, "jykit")
        XCTAssertNotNil(dictionary?["enabled"])
    }

    func testDateRoundTrip() {
        let key = makeKey("date")
        XCTAssertTrue(UserDefaultsManager.save(key: key, value: "2026-01-02 03:04:05", type: .date).success)
        XCTAssertTrue(storedValue(for: key) is Date)
    }

    func testInvalidInputIsRejected() {
        let key = makeKey("invalid")

        let badInt = UserDefaultsManager.save(key: key, value: "abc", type: .int)
        XCTAssertFalse(badInt.success)

        let badJSON = UserDefaultsManager.save(key: key, value: "{not json}", type: .json)
        XCTAssertFalse(badJSON.success)

        let emptyKey = UserDefaultsManager.save(key: "   ", value: "x", type: .string)
        XCTAssertFalse(emptyKey.success)
    }

    func testDetectType() {
        XCTAssertEqual(UserDefaultsManager.detectType(of: true), .bool)
        XCTAssertEqual(UserDefaultsManager.detectType(of: 1), .int)
        XCTAssertEqual(UserDefaultsManager.detectType(of: 1.5), .double)
        XCTAssertEqual(UserDefaultsManager.detectType(of: "text"), .string)
        XCTAssertEqual(UserDefaultsManager.detectType(of: Data([0x01])), .data)
        XCTAssertEqual(UserDefaultsManager.detectType(of: Date()), .date)
        XCTAssertEqual(UserDefaultsManager.detectType(of: ["a": 1]), .json)
    }

    func testSystemKeyDetection() {
        XCTAssertTrue(UserDefaultsManager.isSystemKey("AppleLanguages"))
        XCTAssertTrue(UserDefaultsManager.isSystemKey("NSInterfaceStyle"))
        XCTAssertTrue(UserDefaultsManager.isSystemKey("com.apple.some.key"))
        XCTAssertFalse(UserDefaultsManager.isSystemKey("my.custom.key"))
    }

    func testDeleteRemovesValue() {
        let key = makeKey("delete")
        XCTAssertTrue(UserDefaultsManager.save(key: key, value: "x", type: .string).success)
        UserDefaultsManager.delete(key: key)
        XCTAssertNil(storedValue(for: key))
    }
}

// MARK: - Keychain

final class KeychainManagerTests: XCTestCase {
    private let key = "JYKitTests.keychain.\(UUID().uuidString)"

    override func tearDown() {
        _ = KeychainManager.delete(key: key)
        super.tearDown()
    }

    func testSaveReadDelete() {
        XCTAssertTrue(KeychainManager.save(key: key, value: "secret", type: .string))

        let saved = KeychainManager.getAllItems().first { $0.key == key }
        XCTAssertEqual(saved?.value as? String, "secret")
        XCTAssertEqual(saved?.type, .string)

        XCTAssertTrue(KeychainManager.delete(key: key))
        XCTAssertNil(KeychainManager.getAllItems().first { $0.key == key })
    }

    func testTypedValues() {
        XCTAssertTrue(KeychainManager.save(key: key, value: 100, type: .int))
        let intItem = KeychainManager.getAllItems().first { $0.key == key }
        XCTAssertEqual(intItem?.value as? Int, 100)

        XCTAssertTrue(KeychainManager.save(key: key, value: true, type: .bool))
        let boolItem = KeychainManager.getAllItems().first { $0.key == key }
        XCTAssertEqual(boolItem?.value as? Bool, true)
    }
}

// MARK: - Foundation 扩展

final class DataExtensionTests: XCTestCase {
    func testHexRoundTrip() {
        let data = Data([0x01, 0xAB, 0xFF])
        XCTAssertEqual(data.hexString, "01abff")
        XCTAssertEqual(Data(hexString: "01abff"), data)
    }

    func testInvalidHexReturnsNil() {
        XCTAssertNil(Data(hexString: "zz"))
    }

    func testFormattedDataSize() {
        XCTAssertEqual(UInt64(0).formattedAsDataSize(0), "0B")
        XCTAssertEqual(UInt64(1024).formattedAsDataSize(0), "1KB")
        XCTAssertTrue(UInt64(1536).formattedAsDataSize(1).contains("1.5"))
    }
}

// MARK: - 日志

final class DYLogTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DYLog.sharedInstance.clear()
    }

    override func tearDown() {
        DYLog.sharedInstance.clear()
        super.tearDown()
    }

    func testIncrementalRead() {
        DYLog.sharedInstance.log("first line\n")
        DYLog.sharedInstance.log("second line\n")

        let first = DYLog.sharedInstance.readNewLog(fromOffset: 0)
        XCTAssertTrue(first.text.contains("first line"))
        XCTAssertTrue(first.text.contains("second line"))

        let second = DYLog.sharedInstance.readNewLog(fromOffset: first.offset)
        XCTAssertTrue(second.text.isEmpty)

        DYLog.sharedInstance.log("third line\n")
        let third = DYLog.sharedInstance.readNewLog(fromOffset: second.offset)
        XCTAssertEqual(third.text, "third line\n")
    }

    func testClearResetsContent() {
        DYLog.sharedInstance.log("will be cleared\n")
        DYLog.sharedInstance.clear()

        let result = DYLog.sharedInstance.readNewLog(fromOffset: 0)
        XCTAssertTrue(result.text.isEmpty)
    }
}

// MARK: - 格式化

final class DYUIInspectorFormatterTests: XCTestCase {
    func testRectFormatting() {
        let text = DYUIInspectorFormatter.rect(CGRect(x: 1, y: 2.5, width: 30, height: 40.26))
        XCTAssertEqual(text, "(1.0, 2.5, 30.0, 40.3)")
    }

    func testColorFormatting() {
        let text = DYUIInspectorFormatter.color(UIColor(red: 1, green: 0, blue: 0, alpha: 1))
        XCTAssertEqual(text, "rgba(255.0, 0.0, 0.0, 1.0)")
        XCTAssertEqual(DYUIInspectorFormatter.color(nil), "nil")
    }
}
