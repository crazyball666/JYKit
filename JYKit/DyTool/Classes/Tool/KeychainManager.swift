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
    var service: String?
    var value: Any
    var type: KeychainValueType
    var modified: Date = Date()
}

final class KeychainManager {
    private static let typeCommentPrefix = "JYKit.KeychainValueType."
    private static var defaultService: String? {
        Bundle.main.bundleIdentifier
    }

    /// 列举所有 keychain 条目
    static func getAllItems() -> [KeychainItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
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

            let service = item[kSecAttrService as String] as? String
            let type = metadataType(from: item) ?? inferredType(from: data)
            let modified = item[kSecAttrModificationDate as String] as? Date ?? Date()

            return KeychainItem(
                key: key,
                service: service,
                value: value(from: data, type: type),
                type: type,
                modified: modified
            )
        }
    }

    /// 保存条目（添加或更新）
    static func save(key: String, value: Any, type: KeychainValueType) -> Bool {
        return save(key: key, value: value, type: type, service: defaultService)
    }

    static func save(key: String, value: Any, type: KeychainValueType, service: String?) -> Bool {
        // 先删除旧条目
        let deleteQuery = query(key: key, service: service)
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

        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: finalData,
            kSecAttrComment as String: typeCommentPrefix + type.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        if let service = service, !service.isEmpty {
            addQuery[kSecAttrService as String] = service
        }

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// 删除条目
    static func delete(key: String) -> Bool {
        return delete(key: key, service: defaultService)
    }

    static func delete(key: String, service: String?) -> Bool {
        let status = SecItemDelete(query(key: key, service: service) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func delete(item: KeychainItem) -> Bool {
        return delete(key: item.key, service: item.service)
    }
}

private extension KeychainManager {
    static func query(key: String, service: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        if let service = service, !service.isEmpty {
            query[kSecAttrService as String] = service
        }
        return query
    }

    static func metadataType(from attributes: [String: Any]) -> KeychainValueType? {
        guard let comment = attributes[kSecAttrComment as String] as? String,
              comment.hasPrefix(typeCommentPrefix) else {
            return nil
        }
        let rawValue = String(comment.dropFirst(typeCommentPrefix.count))
        return KeychainValueType(rawValue: rawValue)
    }

    static func inferredType(from data: Data) -> KeychainValueType {
        if data.count == 1, let value = data.first, value == 0 || value == 1 {
            return .bool
        }

        guard let string = String(data: data, encoding: .utf8) else {
            return .data
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "true" || trimmed == "false" {
            return .bool
        }
        if Int(trimmed) != nil {
            return .int
        }
        if Double(trimmed) != nil {
            return .double
        }
        return .string
    }

    static func value(from data: Data, type: KeychainValueType) -> Any {
        switch type {
        case .string:
            return String(data: data, encoding: .utf8) ?? data.hexString
        case .bool:
            if let string = String(data: data, encoding: .utf8) {
                return string == "true" || string == "1"
            }
            return data.first == 1
        case .int:
            guard let string = String(data: data, encoding: .utf8) else { return 0 }
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        case .double:
            guard let string = String(data: data, encoding: .utf8) else { return 0.0 }
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
        case .data:
            return data
        }
    }
}
