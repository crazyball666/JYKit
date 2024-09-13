//
//  Tool.swift
//  SwiftDebug
//
//  Created by 林子鑫 on 2021/11/8.
//

import Foundation
import UIKit
func mainBounds() ->CGRect {
    return UIScreen.main.bounds
}


func DEBUGPrint(_ message: Any? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    // 获取文件名
    let fileName = (file as NSString).lastPathComponent
    // 打印日志内容
    print("【Hook】\(fileName):\(line) \(function) | \(message ?? "")")
    #endif
}



struct Tools {
    // 旋转方向
    static var interfaceOrientation: UIInterfaceOrientation {
        if #available(iOS 13.0, *), let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation {
            return interfaceOrientation
        } else {
            return UIApplication.shared.statusBarOrientation
        }
    }
    
    /// 根VC
    static func rootVC() -> UIViewController? {
        if let window = UIApplication.shared.delegate?.window as? UIWindow {
            return window.rootViewController
        }

        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            return rootVC
        }
        
        if let rootVC = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.rootViewController {
            return rootVC
        }
        
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            return rootVC
        }
        
        print("Fatal error: window or keyWindow is nil")
        return nil
    }
    
    /// 清空KeyChain
    static func clearAllKeyChainItems() {
       var query: [String: Any] = [
                       kSecReturnAttributes as String : kCFBooleanTrue!,
                       kSecMatchLimit as String: kSecMatchLimitAll
                   ]
       
       let secItemClasses: [String] = [ kSecClassGenericPassword as String,
                                        kSecClassInternetPassword as String,
                                        kSecClassCertificate as String,
                                        kSecClassKey as String,
                                        kSecClassIdentity as String]
       
       for secItemClass in secItemClasses {
           query[kSecClass as String] = secItemClass
           
           var result: AnyObject? = nil

           let lastResultCode = withUnsafeMutablePointer(to: &result) {
               SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
           }
           
           if lastResultCode == noErr {
               //print("SecItemCopyMatching error：\(lastResultCode)")
           }

           let spec: [String: Any] = [kSecClass as String: secItemClass]
           let status = SecItemDelete(spec as CFDictionary)
           if status != errSecSuccess {
              //print("SecItemDelete error：\(status)")
           }
       }

       let appDomain = Bundle.main.bundleIdentifier
       UserDefaults.standard.removePersistentDomain(forName: appDomain ?? "")
       UserDefaults.standard.synchronize()
   }
    
    /// 清空 UD
    static func clearAllUserDefault() {
        let userDefaults = UserDefaults.standard
        let dics = userDefaults.dictionaryRepresentation()
        for key in dics {
            userDefaults.removeObject(forKey: key.key)
        }
        userDefaults.synchronize()
    }
    
    /// 显示Alert
    static func showAlert(_ message: String, title: String = "确定", handler: (()->Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction.init(title: title, style: .default, handler: { _ in
            handler?()
        }))
        rootVC()?.topVC().present(alert, animated: true, completion: nil)
    }
    
    static func toJson(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else {
                  return ""
              }
        return str
    }
}
