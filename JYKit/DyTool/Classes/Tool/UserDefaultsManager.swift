//
//  UserDefaultsManager.swift
//  JYKit
//

import Foundation
import UIKit

enum UserDefaultsValueType: String, CaseIterable {
    case string = "String"
    case bool = "Bool"
    case int = "Int"
    case double = "Double"
    case json = "JSON"
    case data = "Data"
    case date = "Date"
}

struct UserDefaultsItem {
    var key: String
    var value: Any
    var type: UserDefaultsValueType
    var isSystemKey: Bool
}

final class UserDefaultsManager {
    static let suite = UserDefaults.standard

    /// 列举所有 UserDefaults 条目
    static func getAllItems() -> [UserDefaultsItem] {
        // 启动参数（NSArgumentDomain）会临时出现在 dictionaryRepresentation 中，列表里不展示
        let argumentKeys = Set(suite.volatileDomain(forName: UserDefaults.argumentDomain).keys)

        let dict = suite.dictionaryRepresentation()
        return dict.compactMap { (key, value) -> UserDefaultsItem? in
            guard !argumentKeys.contains(key) else { return nil }
            let type = detectType(of: value)
            let isSystem = isSystemKey(key)
            return UserDefaultsItem(key: key, value: value, type: type, isSystemKey: isSystem)
        }.sorted { (item1, item2) in
            // 自定义 Key 优先排在前面，系统 Key 排在后面；各自内部按字母升序排列
            if item1.isSystemKey != item2.isSystemKey {
                return !item1.isSystemKey && item2.isSystemKey
            }
            return item1.key.localizedCaseInsensitiveCompare(item2.key) == .orderedAscending
        }
    }

    /// 判断是否是 iOS 系统自动生成的配置项
    static func isSystemKey(_ key: String) -> Bool {
        return key.hasPrefix("Apple") ||
               key.hasPrefix("NS") ||
               key.hasPrefix("AK") ||
               key.hasPrefix("WebKit") ||
               key.hasPrefix("PK") ||
               key.hasPrefix("com.apple")
    }

    /// 推断数据类型
    static func detectType(of value: Any) -> UserDefaultsValueType {
        if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .bool
            }
            if CFNumberIsFloatType(num) {
                return .double
            }
            return .int
        }
        if value is Bool {
            return .bool
        }
        if value is Int || value is Int64 || value is Int32 || value is UInt || value is UInt64 {
            return .int
        }
        if value is Double || value is Float {
            return .double
        }
        if value is Date {
            return .date
        }
        if value is Data {
            return .data
        }
        if value is [Any] || value is [String: Any] || JSONSerialization.isValidJSONObject(value) {
            return .json
        }
        return .string
    }

    /// 保存条目（新增或修改）
    @discardableResult
    static func save(key: String, value: Any, type: UserDefaultsValueType) -> (success: Bool, message: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return (false, "Key 不能为空")
        }

        switch type {
        case .string:
            guard let str = value as? String else {
                return (false, "值必须是字符串")
            }
            suite.set(str, forKey: trimmedKey)

        case .bool:
            if let boolVal = value as? Bool {
                suite.set(boolVal, forKey: trimmedKey)
            } else if let num = value as? NSNumber {
                suite.set(num.boolValue, forKey: trimmedKey)
            } else if let str = value as? String {
                let lower = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if lower == "true" || lower == "1" {
                    suite.set(true, forKey: trimmedKey)
                } else if lower == "false" || lower == "0" {
                    suite.set(false, forKey: trimmedKey)
                } else {
                    return (false, "值必须为 true 或 false")
                }
            } else {
                return (false, "值必须为布尔类型")
            }

        case .int:
            if let intVal = value as? Int {
                suite.set(intVal, forKey: trimmedKey)
            } else if let str = value as? String, let intVal = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                suite.set(intVal, forKey: trimmedKey)
            } else if let num = value as? NSNumber {
                suite.set(num.intValue, forKey: trimmedKey)
            } else {
                return (false, "请输入有效的整数")
            }

        case .double:
            if let dblVal = value as? Double {
                suite.set(dblVal, forKey: trimmedKey)
            } else if let str = value as? String, let dblVal = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                suite.set(dblVal, forKey: trimmedKey)
            } else if let num = value as? NSNumber {
                suite.set(num.doubleValue, forKey: trimmedKey)
            } else {
                return (false, "请输入有效的浮点数")
            }

        case .json:
            if let str = value as? String {
                guard let data = str.data(using: .utf8) else {
                    return (false, "JSON 字符串编码失败")
                }
                do {
                    let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                    suite.set(obj, forKey: trimmedKey)
                } catch {
                    return (false, "JSON 语法解析失败：\(error.localizedDescription)")
                }
            } else if JSONSerialization.isValidJSONObject(value) {
                suite.set(value, forKey: trimmedKey)
            } else {
                return (false, "无效的 JSON 数据")
            }

        case .data:
            if let data = value as? Data {
                suite.set(data, forKey: trimmedKey)
            } else if let str = value as? String {
                if let data = Data(base64Encoded: str) {
                    suite.set(data, forKey: trimmedKey)
                } else {
                    suite.set(Data(str.utf8), forKey: trimmedKey)
                }
            } else {
                return (false, "无效的二进制数据")
            }

        case .date:
            if let date = value as? Date {
                suite.set(date, forKey: trimmedKey)
            } else if let str = value as? String {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: str) {
                    suite.set(date, forKey: trimmedKey)
                } else {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    if let date = df.date(from: str) {
                        suite.set(date, forKey: trimmedKey)
                    } else {
                        return (false, "日期格式错误，请使用 yyyy-MM-dd HH:mm:ss 或 ISO8601")
                    }
                }
            } else {
                return (false, "无效的日期")
            }
        }

        suite.synchronize()
        return (true, "保存成功")
    }

    /// 删除指定 Key
    static func delete(key: String) {
        suite.removeObject(forKey: key)
        suite.synchronize()
    }

    /// 清空所有 App 业务条目。
    /// 注意：会跳过系统自动维护的 Key（如 AppleLanguages），避免破坏 App 语言等系统级设置。
    static func clearAll() {
        let keys = suite.dictionaryRepresentation().keys
        for key in keys where !isSystemKey(key) {
            suite.removeObject(forKey: key)
        }
        suite.synchronize()
    }

    /// 格式化为用于预览展示的字符串
    static func previewString(for value: Any, type: UserDefaultsValueType) -> String {
        switch type {
        case .string:
            return "\(value)"
        case .bool:
            if let num = value as? NSNumber {
                return num.boolValue ? "true" : "false"
            }
            if let b = value as? Bool {
                return b ? "true" : "false"
            }
            return "\(value)"
        case .int, .double:
            return "\(value)"
        case .date:
            if let date = value as? Date {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return df.string(from: date)
            }
            return "\(value)"
        case .data:
            if let data = value as? Data {
                return "Data(\(data.count) bytes)"
            }
            return "\(value)"
        case .json:
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "\(value)"
        }
    }
}
