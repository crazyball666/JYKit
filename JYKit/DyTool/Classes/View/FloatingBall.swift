//
//  FloatingBall.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit


// 悬浮球 Window
class SKFloatingBallWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for view in subviews {
            if !view.isHidden && view.bounds.contains(view.convert(point, from: self)) && view.isKind(of: SKFloatingBallView.self) {
                return true
            }
        }
        return false
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        for child in subviews {
            if child.isKind(of: SKFloatingBallView.self) {
                self.bringSubviewToFront(child)
            }
        }
    }
}


// 悬浮球View
class SKFloatingBallView: UIView {
    
}


// 靠边
enum SKFloatingBallEdgePolicy {
    case allEdge
    case leftRightEdge
    case upDownEdge
}

// 靠边状态
enum SKFloatBallShrinkEdge {
    case left
    case right
    case top
    case bottom
}

// 悬浮球状态
enum SKFloatBallStatus {
    case active   // 活动态
    case shrink   // 收缩态
}

class SKFloatingBall {
    static var `default` = SKFloatingBall(frame: CGRect(x:UIScreen.main.bounds.width, y: UIScreen.main.bounds.height / 2, width: 50, height: 50))
    
    private let window = SKFloatingBallWindow(frame: UIScreen.main.bounds)
    private let contentView: UIView
    private var statusTimer: Timer?
    private var currentShrinkEdge: SKFloatBallShrinkEdge?
    private var status = SKFloatBallStatus.active
    private var isSetup = false
    
    private var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            var safeAreaInsets = UIApplication.shared.keyWindow?.safeAreaInsets ?? .zero
            if Tools.interfaceOrientation == .landscapeRight {
                safeAreaInsets.right = 0
            } else if Tools.interfaceOrientation == .landscapeLeft {
                safeAreaInsets.left = 0
            }
            return safeAreaInsets
        }
        return UIEdgeInsets.zero
    }
    
    private var ballW: CGFloat {
        contentView.frame.size.width
    }
    private var ballH: CGFloat {
        contentView.frame.size.height
    }
    private var windowW: CGFloat {
        window.frame.size.width
    }
    private var windowH: CGFloat {
        window.frame.size.height
    }
    
    var edgePolicy: SKFloatingBallEdgePolicy = .leftRightEdge
    
    
    init(frame: CGRect) {
        window.backgroundColor = .clear
        window.alpha = 1
        window.windowLevel = .init(rawValue: CGFloat(MAXFLOAT))
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        window.rootViewController = vc
        window.isHidden = true
        
        contentView = SKFloatingBallView(frame: frame)
        contentView.backgroundColor = .clear
        let iconView = UIImageView(image: UIImage(inSDK: "icon.png"))
        contentView.addSubview(iconView)
        iconView.frame = contentView.bounds
    
        
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTapFloatingBall)))
        contentView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPanFloatingBall)))
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceOrientationDidChange), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
}


extension SKFloatingBall {
    func install() {
        if contentView.superview == nil {
            window.isHidden = false
            window.addSubview(contentView)
            contentView.alpha = 1
            autoCloseEdge()
        }
    }
    
    func uninstall() {
        if !isSetup { return }
        window.isHidden = true
        contentView.removeFromSuperview()
    }
    
    
    // 自动靠边
    private func autoCloseEdge() {
        destroyTimer()
        var newCenter = contentView.center
        
        var isLeftRight = true
        switch edgePolicy {
        case .allEdge:
            isLeftRight = (windowH - (newCenter.y + ballH / 2)) > 90 && newCenter.y > 90
        case .leftRightEdge:
            isLeftRight = true
        case .upDownEdge:
            isLeftRight = false
        }
                
        if isLeftRight {
            newCenter.y = max(newCenter.y, safeAreaInsets.top)
            newCenter.y = min(newCenter.y, windowH - safeAreaInsets.bottom - ballH / 2)
            
            if newCenter.x < windowW / 2 {
                newCenter.x = safeAreaInsets.left + ballW / 2
                currentShrinkEdge = .left
            } else {
                newCenter.x = windowW - safeAreaInsets.right - ballW / 2
                currentShrinkEdge = .right
            }
            
        } else {
            newCenter.x = max(newCenter.x, safeAreaInsets.left)
            newCenter.x = min(newCenter.x, windowW - safeAreaInsets.right - ballW / 2)
            
            if newCenter.y < windowH / 2 {
                newCenter.y = safeAreaInsets.top + ballH / 2
                currentShrinkEdge = .top
            } else {
                newCenter.y = windowH - safeAreaInsets.bottom - ballH / 2
                currentShrinkEdge = .bottom
            }
        }
        
        
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.contentView.center = newCenter
            self?.contentView.alpha = 1
        }
        
        // 收缩
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { [weak self] _ in
            self?.statusTimer?.invalidate()
            self?.statusTimer = nil
            self?.autoShrink()
        })
    }
    
    // 自动收缩
    private func autoShrink() {
        var newCenter = contentView.center
        switch currentShrinkEdge {
        case .left:
            newCenter.x = safeAreaInsets.left
        case .right:
            newCenter.x = windowW - safeAreaInsets.right
        case .top:
            newCenter.y = safeAreaInsets.top
        case .bottom:
            newCenter.y = windowH - safeAreaInsets.bottom
        default:
            return
        }
        
        status = .shrink
        UIWindow.animate(withDuration: 0.25) { [weak self] in
            self?.contentView.alpha = 0.5
            self?.contentView.center = newCenter
        }
    }
    
    private func destroyTimer() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
}


// MARK: - Actions
extension SKFloatingBall {
    // 点击悬浮球
    @objc private func onTapFloatingBall() {
        switch status {
        case .active:
            guard let topVC = Tools.rootVC()?.topVC(), !topVC.isKind(of: DyNavigationVC.self) else {
                return
            }
            topVC.present(DyNavigationVC(rootViewController: MainToolVC.shared), animated: true, completion: nil)
            
        case .shrink:
            status = .active
            autoCloseEdge()
        }
    }
    
    // 拖动悬浮球
    @objc private func onPanFloatingBall(recognizer: UIPanGestureRecognizer) {
        destroyTimer()
        self.contentView.alpha = 1
        self.currentShrinkEdge = nil
        self.status = .active
        
        
        switch recognizer.state {
        case .began:
            break
        case .changed:
            let trans = recognizer.translation(in: contentView)
            
            var center = contentView.center
            center.x += trans.x
            center.y += trans.y
            contentView.center = center
            
            var frame = contentView.frame
            frame.origin.x = max(frame.origin.x, safeAreaInsets.left)
            frame.origin.x = min(frame.origin.x, windowW - safeAreaInsets.right - ballW / 2)
            frame.origin.y = max(frame.origin.y, safeAreaInsets.top)
            frame.origin.y = min(frame.origin.y, windowH - safeAreaInsets.bottom - ballH / 2)
            contentView.frame = frame
            
            recognizer.setTranslation(.zero, in: contentView)
        case .ended, .cancelled:
            autoCloseEdge()
        default:
            break
        }
    }
    
    // 屏幕旋转
    @objc func onDeviceOrientationDidChange() {
        var frame = contentView.frame
        frame.origin.x = max(frame.origin.x, safeAreaInsets.left)
        frame.origin.x = min(frame.origin.x, windowW - safeAreaInsets.right - ballW / 2)
        frame.origin.y = max(frame.origin.y, safeAreaInsets.top)
        frame.origin.y = min(frame.origin.y, windowH - safeAreaInsets.bottom - ballH / 2)
        contentView.frame = frame
        self.autoShrink()
    }
}


class DyNavigationVC: UINavigationController {
    override func viewDidLoad() {
        view.backgroundColor = .white
        navigationBar.backgroundColor = .white
    }
}
