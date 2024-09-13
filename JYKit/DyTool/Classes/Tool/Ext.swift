//
//  Ext.swift
//  DynamicTools
//
//  Created by crazyball on 2022/7/28.
//

import Foundation

// MARK: - UIViewController
extension UIViewController {
    func topVC() -> UIViewController {
        var topController = self
        while (topController.presentedViewController != nil) {
            topController = topController.presentedViewController!
        }
        return topController
    }
}

// MARK: - UIColor
extension UIColor {
    /// rgba创建UIColor
    convenience init(rgba: String) {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let scanner = Scanner(string: rgba)
        var hexValue: CUnsignedLongLong = 0

        if scanner.scanHexInt64(&hexValue) {
            let length = rgba.count

            switch length {
            case 3:
                r = CGFloat((hexValue & 0xF00) >> 8)    / 15.0
                g = CGFloat((hexValue & 0x0F0) >> 4)    / 15.0
                b = CGFloat(hexValue & 0x00F)           / 15.0
            case 4:
                r = CGFloat((hexValue & 0xF000) >> 12)  / 15.0
                g = CGFloat((hexValue & 0x0F00) >> 8)   / 15.0
                b  = CGFloat((hexValue & 0x00F0) >> 4)  / 15.0
                a = CGFloat(hexValue & 0x000F)          / 15.0
            case 6:
                r = CGFloat((hexValue & 0xFF0000) >> 16)    / 255.0
                g = CGFloat((hexValue & 0x00FF00) >> 8)     / 255.0
                b  = CGFloat(hexValue & 0x0000FF)           / 255.0
            case 8:
                r = CGFloat((hexValue & 0xFF000000) >> 24)  / 255.0
                g = CGFloat((hexValue & 0x00FF0000) >> 16)  / 255.0
                b = CGFloat((hexValue & 0x0000FF00) >> 8)   / 255.0
                a = CGFloat(hexValue & 0x000000FF)          / 255.0
            default:
                print("Invalid number of values (\(length)) in HEX string. Make sure to enter 3, 4, 6 or 8 values. E.g. `aabbccff`")
            }

        } else {
            print("Invalid HEX value: \(rgba)")
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}


// MARK: - Bundle
extension Bundle {
    static var SDK: Bundle {
        return Bundle(path: Bundle(for: DynamicTools.self).bundlePath + "/SDKImages.bundle") ?? Bundle(for: DynamicTools.self)
    }
}

// MARK: - Date
extension Date {
    var time: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return fmt.string(from: self)
    }
}

// MARK: - String
extension String {
    // 计算文本需要的长宽
    // swiftlint:disable line_length
    func textWidth(font: UIFont, height: CGFloat) -> CGFloat {
        return self.boundingRect(with: .init(width: CGFloat.infinity, height: height), options: [.usesFontLeading, .usesLineFragmentOrigin], attributes: [NSAttributedString.Key.font: font], context: nil).size.width
    }
    // swiftlint:disable line_length
    func textHeight(font: UIFont, width: CGFloat) -> CGFloat {
        return self.boundingRect(with: .init(width: width, height: CGFloat.infinity), options: [.usesFontLeading, .usesLineFragmentOrigin], attributes: [NSAttributedString.Key.font: font], context: nil).size.height
    }
}

// MARK: - UIImage
extension UIImage {
    convenience init?(inSDK name: String) {
        self.init(named: name, in: Bundle.SDK, compatibleWith: nil)
    }
}
