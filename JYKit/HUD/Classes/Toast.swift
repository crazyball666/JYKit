//
//  Toast.swift
//  JYKit
//
//  Created by crazyball on 2023/7/26.
//

import UIKit


public struct JYToast {
    private static var containerView: UIView? {
        if #available(iOS 13.0, *) {
            let frontToBackWindows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap { $0.windows }
                .reversed()
            for window in frontToBackWindows {
                if window.screen == UIScreen.main,
                   !window.isHidden && window.alpha > 0,
                   window.isKeyWindow {
                    return window
                }
            }
        }

        let frontToBackWindows = UIApplication.shared.windows.reversed()
        for window in frontToBackWindows {
            if window.screen == UIScreen.main,
               !window.isHidden && window.alpha > 0,
               window.isKeyWindow {
                return window
            }
        }
        return nil
    }
    
    private static var currentToast: ToastView?
    
    public static func show(_ text: String, delay: TimeInterval = 2) {
        DispatchQueue.main.async {
            guard let container = self.containerView else {
                return
            }

            if let currentToast = self.currentToast {
                self.currentToast = nil
                dissmiss(toastView: currentToast)
            }
            
            let toastView = ToastView(text: text, container: container)
            currentToast = toastView
            container.addSubview(toastView)
            toastView.setInitialState()
            UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .curveEaseIn, .beginFromCurrentState]) {
                toastView.setPresentState()
            } completion: { _ in
                toastView.timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { _ in
                    self.dissmiss(toastView: toastView)
                })
            }
        }
    }
    
    private static func dissmiss(toastView: ToastView) {
        toastView.timer?.invalidate()
        toastView.timer = nil
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .curveEaseIn, .beginFromCurrentState]) {
                toastView.setDismissState()
            } completion: { _ in
                toastView.removeFromSuperview()
            }
        }
    }
}

fileprivate class ToastView: UIVisualEffectView {
    var timer: Timer?
    private let text: String
    private let container: UIView
    private let maxLabelWidth: CGFloat = 250
    private let labelFont = UIFont.systemFont(ofSize: 12)
    private let cornerRadius: CGFloat = 12
    private let horizontalSpacing: CGFloat = 12
    private let verticalSpacing: CGFloat = 12

    private lazy var labelView: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        label.baselineAdjustment = .alignCenters
        label.numberOfLines = 0
        label.textColor = .white
        label.font = labelFont
        self.contentView.addSubview(label)
        return label
    }()


    init(text: String, container: UIView) {
        self.text = text
        self.container = container
        super.init(effect: UIBlurEffect(style: .dark))
        setupUI()
    }
    
    required init?(coder: NSCoder) { return nil }
    
    private func setupUI() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = cornerRadius
        self.transform = CGAffineTransform.identity
        self.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin]
        self.alpha = 0
        
        labelView.text = self.text
        
        let labelSize = getLabelSize(text: text, font: labelFont, maxWidth: maxLabelWidth)

        frame = CGRect(x: 0, y: 0, width: labelSize.width + horizontalSpacing * 2, height: labelSize.height + verticalSpacing * 2)
        labelView.frame.size = labelSize
        labelView.center = contentView.center
    }
    
    private func getLabelSize(text: String, font: UIFont, maxWidth: CGFloat) -> CGSize {
        let constraintSize = CGSize(width: maxWidth, height: maxWidth)
        return NSString(string: text)
            .boundingRect(
                with: constraintSize,
                options: [.usesFontLeading, .truncatesLastVisibleLine, .usesLineFragmentOrigin],
                attributes: [NSAttributedString.Key.font: font],
                context: nil
            ).size
    }
}


fileprivate extension ToastView {
    func setInitialState() {
        self.alpha = 0
        self.center = container.center
        self.frame.origin.y = -self.frame.height
    }

    func setPresentState() {
        self.alpha = 1
        self.frame.origin.y = container.safeAreaInsets.top
    }
    
    func setDismissState() {
        self.setInitialState()
    }
}
