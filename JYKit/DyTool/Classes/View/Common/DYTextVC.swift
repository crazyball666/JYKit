//
//  DYTextVC.swift
//  JYKit
//

import UIKit

/// 通用只读文本查看控制器，供启动参数、调用栈等页面复用。
class DYTextVC: DYBaseVC {
    private let textView = UITextView()
    private let content: String
    private let monospaced: Bool

    init(title: String, content: String, monospaced: Bool = true) {
        self.content = content
        self.monospaced = monospaced
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DYStyle.background

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.font = monospaced
            ? DYStyle.monospacedFont(size: 12)
            : .systemFont(ofSize: 15)
        // 深色代码背景必须配浅色文字，否则浅色模式下文字几乎看不见
        textView.backgroundColor = DYStyle.codeBackground
        textView.textColor = .white
        textView.indicatorStyle = .white
        if #available(iOS 13.0, *) {
            textView.tintColor = .systemBlue
        }
        textView.text = content
        view.addSubview(textView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "复制",
            style: .done,
            target: self,
            action: #selector(copyAll)
        )

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func copyAll() {
        UIPasteboard.general.string = content
        JYToast.show("已复制")
    }
}
