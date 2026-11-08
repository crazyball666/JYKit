//
//  DYMainWindow.swift
//  JYKit
//
//  Created by crazyball on 2025/3/1.
//

import UIKit

// 悬浮球 Window
class DYMainWindow: UIWindow {
    static let shared = DYMainWindow(frame: UIScreen.main.bounds)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.windowLevel = .statusBar + 1
        
        // 要设置 root vc，否则 window 不会旋转
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        self.rootViewController = vc
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// 适配 iOS 13+ UIScene 架构，确保悬浮窗挂载到活跃的 UIWindowScene 上渲染
    func attachToActiveSceneIfNeeded() {
        if #available(iOS 13.0, *) {
            if self.windowScene == nil {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                let activeScene = scenes.first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
                    ?? scenes.first
                if let scene = activeScene {
                    self.windowScene = scene
                }
            }
        }
        self.isHidden = false
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for view in subviews {
            if !view.isHidden && view.bounds.contains(view.convert(point, from: self)) && view.isKind(of: DYFloatingView.self) {
                return true
            }
        }
        return false
    }
    
    override func addSubview(_ view: UIView) {
        attachToActiveSceneIfNeeded()
        super.addSubview(view)
        for child in subviews {
            if child.isKind(of: DYFloatingView.self) {
                self.bringSubviewToFront(child)
            }
        }
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override func makeKey() {}
    
    override func makeKeyAndVisible() {}
}


