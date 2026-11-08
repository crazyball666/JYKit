//
//  DYStyle.swift
//  JYKit
//

import UIKit

/// DyTool 统一视觉样式，集中管理配色与字体，兼容深色模式。
enum DYStyle {
    static var background: UIColor {
        if #available(iOS 13.0, *) {
            return .systemBackground
        }
        return .white
    }

    static var groupedBackground: UIColor {
        if #available(iOS 13.0, *) {
            return .systemGroupedBackground
        }
        return UIColor(white: 0.95, alpha: 1)
    }

    static var secondaryBackground: UIColor {
        if #available(iOS 13.0, *) {
            return .secondarySystemBackground
        }
        return UIColor(white: 0.97, alpha: 1)
    }

    static var separator: UIColor {
        if #available(iOS 13.0, *) {
            return .separator
        }
        return UIColor(white: 0.85, alpha: 1)
    }

    static var text: UIColor {
        if #available(iOS 13.0, *) {
            return .label
        }
        return .black
    }

    static var secondaryText: UIColor {
        if #available(iOS 13.0, *) {
            return .secondaryLabel
        }
        return UIColor(white: 0.45, alpha: 1)
    }

    /// 代码编辑器背景（保持黑底，与控制台观感一致）
    static var codeBackground: UIColor {
        return UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
    }

    static func monospacedFont(size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func tintedBackground(_ color: UIColor) -> UIColor {
        return color.withAlphaComponent(0.14)
    }
}
