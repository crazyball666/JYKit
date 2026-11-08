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
        DYLagMonitor.shared.startIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showBall()
        }

        // 便于自动化调试：启动参数带 -JYKitShowPanel 时直接打开工具主界面
        if ProcessInfo.processInfo.arguments.contains("-JYKitShowPanel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                DYMainVC.shared.present()
            }
        }
    }

    /// 显示悬浮球
    public static func showBall() {
        DYFloatingBall.default.install()
        DYMonitorView.shared.install()
    }

    public static func setLagMonitorEnabled(_ enabled: Bool) {
        DYLagMonitor.shared.setEnabled(enabled)
    }

    public static func setLagMonitorThreshold(_ threshold: TimeInterval) {
        DYLagMonitor.shared.setThreshold(threshold)
    }

    public static func setLagMonitorThresholdMilliseconds(_ milliseconds: Double) {
        DYLagMonitor.shared.setThreshold(milliseconds / 1000)
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
