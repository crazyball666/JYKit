//
//  DYLogVC.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

class DYLogVC: DYBaseVC {
    let searchBar = UISearchBar()
    let textView = UITextView()
    let switchView = UISwitch()
    var timer: Timer?
    private var currentLog: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "日志监控"
        view.addSubview(searchBar)
        view.addSubview(textView)
        searchBar.placeholder = "搜索日志"
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.isEditable = false
        textView.font = UIFont(name: "Menlo", size: 12) ?? .systemFont(ofSize: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        searchBar.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        searchBar.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        textView.topAnchor.constraint(equalTo: searchBar.bottomAnchor).isActive = true
        textView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        textView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        switchView.isOn = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: {[weak self] timer in
            self?.loadLog()
        })
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(onTapClear)),
            UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(onTapExport)),
            UIBarButtonItem(customView: switchView)
        ]
        loadLog()
    }
    
    @objc func onTapExport() {
        guard let sdFile = try? SDFileManager.shared.getFile(DYLog.sharedInstance.logFilePath) else { return }
        let filePath = URL(fileURLWithPath: sdFile.filepath)
        let air = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
        self.present(air, animated: true, completion: nil)
    }

    @objc func onTapClear() {
        Tools.showAlert(title: "确认清空日志？", confirmHandler: { [weak self] in
            DYLog.sharedInstance.clear()
            self?.currentLog = ""
            self?.applyFilter()
            JYToast.show("日志已清空")
        })
    }
    
    
    func loadLog() {
        guard switchView.isOn else { return }
        let log = DYLog.sharedInstance.getStdLog()
        currentLog = log
        applyFilter()
    }

    private func applyFilter() {
        let keyword = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayText: String
        if keyword.isEmpty {
            displayText = currentLog
        } else {
            displayText = currentLog
                .components(separatedBy: .newlines)
                .filter { $0.localizedCaseInsensitiveContains(keyword) }
                .joined(separator: "\n")
        }
        textView.text = displayText
        if !displayText.isEmpty {
            let textCount: Int = textView.text.count
            guard textCount >= 1 else { return }
            textView.scrollRangeToVisible(NSRange(location: textCount - 1, length: 1))
        }
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
}

extension DYLogVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
