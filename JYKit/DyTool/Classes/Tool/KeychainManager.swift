import Foundation
import Security

enum KeychainValueType: String, CaseIterable {
    case string = "String"
    case bool = "Bool"
    case int = "Int"
    case double = "Double"
    case data = "Data"
}

struct KeychainItem {
    var key: String
    var value: Any
    var type: KeychainValueType
    var modified: Date = Date()
}

final class KeychainManager {

    /// 列举所有 keychain 条目
    static func getAllItems() -> [KeychainItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> KeychainItem? in
            guard let key = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else {
                return nil
            }

            // Only treat as String if valid UTF-8 encoding
            if let str = String(data: data, encoding: .utf8) {
                // Check if it's a "true"/"false" string for Bool
                if str == "true" || str == "false" {
                    return KeychainItem(key: key, value: str == "true", type: .bool)
                }
                return KeychainItem(key: key, value: str, type: .string)
            }

            // Only treat as known numeric types if data length matches exactly
            // Numbers are stored as UTF-8 string representation
            if let num = Int(String(data: data, encoding: .utf8) ?? "") {
                return KeychainItem(key: key, value: num, type: .int)
            }

            if let num = Double(String(data: data, encoding: .utf8) ?? "") {
                return KeychainItem(key: key, value: num, type: .double)
            }

            // Default to Data when format is unclear
            return KeychainItem(key: key, value: data, type: .data)
        }
    }

    /// 保存条目（添加或更新）
    static func save(key: String, value: Any, type: KeychainValueType) -> Bool {
        // 先删除旧条目
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 转换为 data
        var data: Data?
        switch type {
        case .string:
            if let str = value as? String {
                data = str.data(using: .utf8)
            }
        case .bool:
            if let bool = value as? Bool {
                data = (bool ? "true" : "false").data(using: .utf8)
            }
        case .int:
            if let num = value as? Int {
                data = String(num).data(using: .utf8)
            }
        case .double:
            if let num = value as? Double {
                data = String(num).data(using: .utf8)
            }
        case .data:
            data = value as? Data
        }

        guard let finalData = data else { return false }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecAttrAccount as String: key,
            kSecValueData as String: finalData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// 删除条目
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
