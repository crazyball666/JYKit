//
//  DYFloatingView.swift
//  JYKit
//
//  Created by crazyball on 2025/11/25.
//

import UIKit

// 靠边
enum DYFloatingEdgePolicy {
    case allEdge
    case leftRightEdge
    case upDownEdge
}

// 靠边状态
enum DYFloatingEdgeStatus {
    case left
    case right
    case top
    case bottom
}

class DYFloatingView: UIView {
    var edgePolicy: DYFloatingEdgePolicy = .leftRightEdge
    var panGestureRecognizer: UIPanGestureRecognizer?
    var tapGestureRecognizer: UITapGestureRecognizer?
    
    // 悬浮窗的安全区域
    var safeFloatingAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            var safeAreaInsets = UIApplication.shared.currentKeyWindow?.safeAreaInsets ?? .zero
            let currentInterfaceOrientation = UIApplication.shared.currentInterfaceOrientation
            if currentInterfaceOrientation == .landscapeRight {
                safeAreaInsets.right = 0
            } else if currentInterfaceOrientation == .landscapeLeft {
                safeAreaInsets.left = 0
            }
            return safeAreaInsets
        }
        return UIEdgeInsets.zero
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func install() {
        if self.superview == nil {
            DYFMainWindow.shared.addSubview(self)
            
            if tapGestureRecognizer == nil {
                tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onTap))
                self.addGestureRecognizer(tapGestureRecognizer!)
            }
            if panGestureRecognizer == nil {
                panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(onPan))
                self.addGestureRecognizer(panGestureRecognizer!)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(onDeviceOrientationDidChange), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
        }
    }
    
    func uninstall() {
        self.removeFromSuperview()
        
        if let tapGestureRecognizer = self.tapGestureRecognizer {
            self.removeGestureRecognizer(tapGestureRecognizer)
            self.tapGestureRecognizer = nil
        }
        if let panGestureRecognizer = self.panGestureRecognizer {
            self.removeGestureRecognizer(panGestureRecognizer)
            self.panGestureRecognizer = nil
        }
        NotificationCenter.default.removeObserver(self, name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
    @objc func onTap() {}
    
    @objc func onPan(recognizer: UIPanGestureRecognizer) {
        let safeAreaInsets = self.safeFloatingAreaInsets
        let superviewFrame = self.superview?.frame ?? .zero
        
        switch recognizer.state {
        case .began:
            break
        case .changed:
            let trans = recognizer.translation(in: self)
            var center = self.center
            center.x = min(max(center.x + trans.x, self.frame.width / 2 + safeAreaInsets.left), superviewFrame.width - safeAreaInsets.right - self.frame.width / 2)
            center.y = min(max(center.y + trans.y, self.frame.height / 2 + safeAreaInsets.top), superviewFrame.height - safeAreaInsets.bottom - self.frame.height / 2)
            self.center = center
            recognizer.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            autoCloseEdge()
        default:
            break
        }
    }
    
    @objc func onDeviceOrientationDidChange() {
        autoCloseEdge()
    }
    
    // 自动靠边
    func autoCloseEdge() {
        let status: DYFloatingEdgeStatus
        var closeCenter = self.center
        let safeAreaInsets = self.safeFloatingAreaInsets
        let superviewFrame = self.superview?.frame ?? .zero
        
        let isLeftRight: Bool
        switch edgePolicy {
        case .allEdge:
            isLeftRight = (superviewFrame.height - (closeCenter.y + self.frame.height / 2)) > 90 && closeCenter.y > 90
        case .leftRightEdge:
            isLeftRight = true
        case .upDownEdge:
            isLeftRight = false
        }
                
        if isLeftRight {
            closeCenter.y = min(max(closeCenter.y, self.frame.height / 2 + safeAreaInsets.top), superviewFrame.height - safeAreaInsets.bottom - self.frame.height / 2)
            if closeCenter.x < superviewFrame.width / 2 {
                closeCenter.x = safeAreaInsets.left + self.frame.width / 2
                status = .left
            } else {
                closeCenter.x = superviewFrame.width - safeAreaInsets.right - self.frame.width / 2
                status = .right
            }
        } else {
            closeCenter.x = min(max(closeCenter.x, self.frame.width / 2 + safeAreaInsets.left), superviewFrame.width - safeAreaInsets.right - self.frame.width / 2)
            if closeCenter.y < superviewFrame.height / 2 {
                closeCenter.y = safeAreaInsets.top + self.frame.height / 2
                status = .top
            } else {
                closeCenter.y = superviewFrame.height - safeAreaInsets.bottom - self.frame.height / 2
                status = .right
            }
        }
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.center = closeCenter
        } completion: { _ in
            self.onColseEdgeCompleted(status: status)
        }
    }
    
    // 靠边结束
    func onColseEdgeCompleted(status: DYFloatingEdgeStatus) {}
}

extension DYFloatingView {}
