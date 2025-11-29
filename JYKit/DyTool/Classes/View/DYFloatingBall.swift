//
//  DYFloatingBall.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

// 悬浮球状态
enum DYFloatBallStatus {
    case active   // 活动态
    case shrink   // 收缩态
}

class DYFloatingBall: DYFloatingView {
    static var `default` = DYFloatingBall()
    
    private var statusTimer: Timer?
    private var status = DYFloatBallStatus.active
    
    init() {
        super.init(frame: .init(origin: .zero, size: .init(width: 50, height: 50)))
        self.backgroundColor = .clear
        let iconView = UIImageView(image: UIImage(inSDK: "icon.png"))
        self.addSubview(iconView)
        iconView.frame = self.bounds
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    
    override func install() {
        if self.superview == nil {
            super.install()
            self.frame.origin = .init(x: superview!.frame.width, y: superview!.frame.height / 2)
            autoCloseEdge()
        }
    }
    
    override func onTap() {
        super.onTap()
        switch status {
        case .active:
            DYMainVC.shared.present()
        case .shrink:
            status = .active
            self.alpha = 1
            autoCloseEdge()
        }
    }
    
    override func onPan(recognizer: UIPanGestureRecognizer) {
        destroyTimer()
        self.alpha = 1
        super.onPan(recognizer: recognizer)
    }
    
    // 自动靠边
    override func autoCloseEdge() {
        destroyTimer()
        super.autoCloseEdge()
    }
    
    override func onColseEdgeCompleted(status: DYFloatingEdgeStatus) {
        var shirkCenter = self.center
        let superviewFrame = self.superview?.frame ?? .zero
        switch status {
        case .left:
            shirkCenter.x = self.safeFloatingAreaInsets.left
        case .right:
            shirkCenter.x = superviewFrame.width - safeFloatingAreaInsets.right
        case .top:
            shirkCenter.y = self.safeFloatingAreaInsets.top
        case .bottom:
            shirkCenter.y = superviewFrame.height - safeFloatingAreaInsets.bottom
        }
        // 收缩
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { [weak self] _ in
            self?.statusTimer?.invalidate()
            self?.statusTimer = nil
            self?.status = .shrink
            UIWindow.animate(withDuration: 0.25) { [weak self] in
                self?.alpha = 0.5
                self?.center = shirkCenter
            }
        })
    }
}


extension DYFloatingBall {
    private func destroyTimer() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
}
