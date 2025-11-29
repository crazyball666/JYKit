//
//  DYMainWindow.swift
//  JYKit
//
//  Created by crazyball on 2025/3/1.
//

import Foundation


// 悬浮球 Window
class DYFMainWindow: UIWindow {
    static let shared = DYFMainWindow(frame: UIScreen.main.bounds)

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.windowLevel = .statusBar + 1
        self.isHidden = false
        
        // 要设置 root vc，否则 window 不会旋转
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        self.rootViewController = vc
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
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


