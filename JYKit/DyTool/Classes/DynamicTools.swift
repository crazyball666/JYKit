//
//  SwiftDebug.swift
//  SwiftDebug
//
//  Created by 林子鑫 on 2021/11/8.
//

import Foundation
import UIKit


@objcMembers
@objc public class DynamicTools: NSObject {
    
    /// 初始化
    public static func setup() {
        print("加载注入模块成功")
        
        // 日志Hook
        PrintHook.shared().hook()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showBall()
        }
    }
    
    /// 显示悬浮球
    public static func showBall() {
        SKFloatingBall.default.install()
    }
}



extension UIWindow {    
    open override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            DynamicTools.showBall()
        }
    }
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            DynamicTools.showBall()
        }
    }
}
