//
//  DYLogVC.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

class DYLogVC: DYBaseVC {
    private let searchBar = UISearchBar()
    private let textView = UITextView()
    private let liveSwitch = UISwitch()
    private let liveLabel = UILabel()
    private var timer: Timer?

    /// 已加载的完整日志内容（用于搜索过滤）
    private var logText: String = ""
    /// 已读取到的文件偏移量，增量读取使用
    private var readOffset: UInt64 = 0
    /// 是否跟随最新日志滚动到底部
    private var isFollowTail = true
    private var isRendering = false

    /// 内存中最多保留的日志字符数，避免长时间运行占用过高
    private let maxCachedCharacters = 300_000
    private let refreshInterval: TimeInterval = 2

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "日志监控"

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(onTapClear)),
            UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(onTapExport))
        ]

        setupUI()

        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true, block: { [weak self] _ in
            self?.loadLog()
        })
        RunLoop.main.add(timer!, forMode: .common)

        loadLog()
    }

    private func setupUI() {
        let header = UIView()
        header.backgroundColor = DYStyle.secondaryBackground
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        searchBar.placeholder = "搜索日志"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(searchBar)

        liveLabel.text = "实时刷新"
        liveLabel.font = .systemFont(ofSize: 12)
        liveLabel.textColor = DYStyle.secondaryText
        liveLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(liveLabel)

        liveSwitch.isOn = true
        liveSwitch.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        liveSwitch.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(liveSwitch)

        textView.backgroundColor = DYStyle.codeBackground
        textView.textColor = .white
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.font = DYStyle.monospacedFont(size: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        view.addSubview(textView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),

            searchBar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 4),
            searchBar.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            searchBar.trailingAnchor.constraint(equalTo: liveLabel.leadingAnchor, constant: -4),

            liveLabel.trailingAnchor.constraint(equalTo: liveSwitch.leadingAnchor, constant: -2),
            liveLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            liveSwitch.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            liveSwitch.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            textView.topAnchor.constraint(equalTo: header.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc func onTapExport() {
        guard let sdFile = try? SDFileManager.shared.getFile(DYLog.sharedInstance.logFilePath) else {
            JYToast.show("日志文件不存在")
            return
        }
        let filePath = URL(fileURLWithPath: sdFile.filepath)
        let air = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            air.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(air, animated: true, completion: nil)
    }

    @objc func onTapClear() {
        Tools.showAlert(title: "确认清空日志？", confirmHandler: { [weak self] in
            DYLog.sharedInstance.clear()
            self?.logText = ""
            self?.readOffset = 0
            self?.isFollowTail = true
            self?.render()
            JYToast.show("日志已清空")
        })
    }

    /// 增量读取日志，避免每次刷新都读取整个文件。
    func loadLog() {
        guard liveSwitch.isOn else { return }
        let (newText, newOffset) = DYLog.sharedInstance.readNewLog(fromOffset: readOffset)
        readOffset = newOffset
        guard !newText.isEmpty else { return }

        logText += newText
        if logText.count > maxCachedCharacters {
            let dropCount = logText.count - maxCachedCharacters / 2
            logText = String(logText.dropFirst(dropCount))
        }
        render()
    }

    private func filteredText() -> String {
        let keyword = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !keyword.isEmpty else {
            return logText
        }
        return logText
            .components(separatedBy: .newlines)
            .filter { $0.localizedCaseInsensitiveContains(keyword) }
            .joined(separator: "\n")
    }

    private func render() {
        isRendering = true
        let previousOffset = textView.contentOffset
        textView.text = filteredText()
        isRendering = false

        if isFollowTail {
            scrollToBottom()
        } else if textView.contentSize.height > textView.bounds.height {
            let maxY = textView.contentSize.height - textView.bounds.height
            textView.contentOffset = CGPoint(x: 0, y: min(previousOffset.y, maxY))
        }
    }

    private func scrollToBottom() {
        let bottom = max(0, textView.contentSize.height - textView.bounds.height)
        textView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
    }

    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
}

extension DYLogVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        isFollowTail = searchText.isEmpty
        render()
        if !searchText.isEmpty {
            textView.setContentOffset(.zero, animated: false)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension DYLogVC: UITextViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isRendering else { return }
        let distanceToBottom = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height
        isFollowTail = distanceToBottom <= 40
    }
}
