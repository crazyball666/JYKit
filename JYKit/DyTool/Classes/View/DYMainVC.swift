//
//  DYMainVC.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

fileprivate struct ToolItem {
    var title: String
    var selector: Selector
    var userInfo: Any?
}

class DYMainVC: UINavigationController {
    static let shared = DYMainVC(rootViewController: MainToolVC())
    
    override func viewDidLoad() {
        view.backgroundColor = .white
        navigationBar.backgroundColor = .white
    }
    
    func present() {
        guard let topVC = Tools.rootVC()?.topVC(), topVC != self else {
            return
        }
        if self.isBeingPresented {
            self.dismiss(animated: false) {
                topVC.present(self, animated: true, completion: nil)
            }
            return
        }
        topVC.present(self, animated: true, completion: nil)
    }
    
    func dismiss() {
        self.dismiss(animated: true)
    }
}


fileprivate class MainToolVC: DYBaseVC {
    private var tableView = UITableView()
    private var items = [
        ToolItem(title: "日志查看", selector: #selector(showLogs)),
        ToolItem(title: "悬浮监控设置", selector: #selector(showMonitorSettings)),
        ToolItem(title: "UI层级查看", selector: #selector(showUIInspector)),
        ToolItem(title: "卡顿监控", selector: #selector(showLagMonitor)),
        ToolItem(title: "清空KeyChain", selector: #selector(clearKeyChain)),
        ToolItem(title: "Keychain管理", selector: #selector(showKeychain)),
        ToolItem(title: "UserDefaults管理", selector: #selector(showUserDefaults)),
        ToolItem(title: "清空UserDefault", selector: #selector(clearUserDefault)),
        ToolItem(title: "App现场信息", selector: #selector(showAppInfo)),
        ToolItem(title: "获取ProcessInfo参数", selector: #selector(getProcessInfo)),
        ToolItem(title: "沙盒文件管理", selector: #selector(goFileManage)),
        ToolItem(title: "包体文件管理", selector: #selector(goAppFileManage)),
//        ToolItem(title: "测试Crash", selector: #selector(testCrash)),
//        ToolItem(title: "Crash日志", selector: #selector(exportCrash)),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = DYToolRuntimeInfo.version
        print("DyTool main menu loaded: \(items.map { $0.title }.joined(separator: ", "))")
        
        view.addSubview(tableView)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MainToolCell")
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}


extension MainToolVC {
    @objc func showLogs() {
        navigationController?.pushViewController(DYLogVC(), animated: true)
    }
    
    @objc func showMonitorSettings() {
        navigationController?.pushViewController(DYMonitorSettingsVC(), animated: true)
    }

    @objc func showUIInspector() {
        navigationController?.pushViewController(DYUIInspectorVC(), animated: true)
    }

    @objc func showLagMonitor() {
        navigationController?.pushViewController(DYLagMonitorVC(), animated: true)
    }
    
    @objc func clearKeyChain() {
        Tools.showAlert(title: "确认清空 KeyChain？", confirmHandler: {
            Tools.clearAllKeyChainItems()
            JYToast.show("已清空KeyChain")
        })
    }

    @objc func showKeychain() {
        navigationController?.pushViewController(KeychainListVC(), animated: true)
    }

    @objc func showUserDefaults() {
        navigationController?.pushViewController(UserDefaultsListVC(), animated: true)
    }

    @objc func clearUserDefault() {
        Tools.showAlert(title: "确认清空 UserDefault？", confirmHandler: {
            Tools.clearAllUserDefault()
            JYToast.show("已清空UserDefault")
        })
    }

    @objc func showAppInfo() {
        navigationController?.pushViewController(AppInfoVC(), animated: true)
    }
    
    @objc func getProcessInfo() {
        let args = ProcessInfo.processInfo.arguments
        Tools.showAlert("\(args)")
    }
    
    @objc func goFileManage() {
        navigationController?.pushViewController(DirectoryManageVC(path: NSHomeDirectory()), animated: true)
    }
    
    @objc func goAppFileManage() {
        navigationController?.pushViewController(DirectoryManageVC(path: Bundle.main.bundlePath), animated: true)
    }
}

private class DYMonitorMetricCell: UITableViewCell {
    static let identifier = "DYMonitorMetricCell"

    let toggle = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        accessoryView = toggle
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        accessoryView = toggle
    }
}

private class DYMonitorSettingsVC: DYBaseVC {
    private enum Section: Int, CaseIterable {
        case monitor
        case metrics
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let metrics = DYMonitorMetric.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "悬浮监控设置"

        tableView.register(DYMonitorMetricCell.self, forCellReuseIdentifier: DYMonitorMetricCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func onMonitorToggleChanged(_ sender: UISwitch) {
        DYMonitorConfiguration.shared.setMonitoringEnabled(sender.isOn)
        DYMonitorView.shared.reloadConfiguration()
    }

    @objc private func onToggleChanged(_ sender: UISwitch) {
        guard metrics.indices.contains(sender.tag) else {
            return
        }
        DYMonitorConfiguration.shared.setEnabled(sender.isOn, for: metrics[sender.tag])
        DYMonitorView.shared.reloadConfiguration()
    }
}

extension DYMonitorSettingsVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .monitor:
            return 1
        case .metrics:
            return metrics.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DYMonitorMetricCell.identifier, for: indexPath) as! DYMonitorMetricCell
        cell.toggle.removeTarget(nil, action: nil, for: .valueChanged)

        guard let section = Section(rawValue: indexPath.section) else {
            return cell
        }

        switch section {
        case .monitor:
            cell.textLabel?.text = "悬浮监控"
            cell.toggle.tag = 0
            cell.toggle.isOn = DYMonitorConfiguration.shared.isMonitoringEnabled
            cell.toggle.addTarget(self, action: #selector(onMonitorToggleChanged), for: .valueChanged)
        case .metrics:
            let metric = metrics[indexPath.row]
            cell.textLabel?.text = metric.title
            cell.toggle.tag = indexPath.row
            cell.toggle.isOn = DYMonitorConfiguration.shared.isEnabled(metric)
            cell.toggle.addTarget(self, action: #selector(onToggleChanged), for: .valueChanged)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? DYMonitorMetricCell else {
            return
        }
        cell.toggle.setOn(!cell.toggle.isOn, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .monitor:
            onMonitorToggleChanged(cell.toggle)
        case .metrics:
            onToggleChanged(cell.toggle)
        }
    }
}

private struct DebugInfoItem {
    let title: String
    let value: String
}

private class DebugInfoCell: UITableViewCell {
    static let identifier = "DebugInfoCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        detailTextLabel?.font = .systemFont(ofSize: 12)
        detailTextLabel?.textColor = .gray
        detailTextLabel?.numberOfLines = 2
        selectionStyle = .default
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

private class AppInfoVC: DYBaseVC {
    private let tableView = UITableView()
    private var items: [DebugInfoItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "App现场信息"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(exportInfo)),
            navigationItem.rightBarButtonItem
        ].compactMap { $0 }

        tableView.register(DebugInfoCell.self, forCellReuseIdentifier: DebugInfoCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reloadItems()
    }

    private func reloadItems() {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]
        let process = ProcessInfo.processInfo
        let memory = ProcessInfo.processInfo.physicalMemory

        items = [
            DebugInfoItem(title: "App名称", value: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? ""),
            DebugInfoItem(title: "Bundle ID", value: bundle.bundleIdentifier ?? ""),
            DebugInfoItem(title: "版本号", value: info["CFBundleShortVersionString"] as? String ?? ""),
            DebugInfoItem(title: "Build", value: info["CFBundleVersion"] as? String ?? ""),
            DebugInfoItem(title: "Bundle路径", value: bundle.bundlePath),
            DebugInfoItem(title: "沙盒路径", value: NSHomeDirectory()),
            DebugInfoItem(title: "系统", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"),
            DebugInfoItem(title: "设备型号", value: JYDeviceInfo.deviceModel()),
            DebugInfoItem(title: "设备平台", value: JYDeviceInfo.platform()),
            DebugInfoItem(title: "CPU核心数", value: "\(JYDeviceInfo.cpuCount())"),
            DebugInfoItem(title: "物理内存", value: memory.formattedAsDataSize()),
            DebugInfoItem(title: "进程内存", value: JYDeviceInfo.footprintMemory().formattedAsDataSize()),
            DebugInfoItem(title: "可用内存", value: JYDeviceInfo.availableMemory().formattedAsDataSize()),
            DebugInfoItem(title: "是否调试中", value: JYDeviceInfo.isBeingDebugged() ? "true" : "false"),
            DebugInfoItem(title: "启动参数", value: process.arguments.joined(separator: "\n"))
        ]
    }

    @objc private func exportInfo() {
        let text = items.map { "\($0.title): \($0.value)" }.joined(separator: "\n")
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activity.popoverPresentationController?.sourceView = view
        }
        present(activity, animated: true)
    }
}

extension AppInfoVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DebugInfoCell.identifier, for: indexPath) as! DebugInfoCell
        let item = items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.value
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIPasteboard.general.string = items[indexPath.row].value
        JYToast.show("已复制")
    }
}

private class UserDefaultsListVC: DYBaseVC {
    private let tableView = UITableView()
    private var items: [(key: String, value: Any)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "UserDefaults"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadData)),
            navigationItem.rightBarButtonItem
        ].compactMap { $0 }

        tableView.register(DebugInfoCell.self, forCellReuseIdentifier: DebugInfoCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reloadData()
    }

    @objc private func reloadData() {
        items = UserDefaults.standard.dictionaryRepresentation()
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        tableView.reloadData()
    }

    private func previewValue(_ value: Any) -> String {
        if let data = value as? Data {
            return "Data(\(data.count) bytes)"
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(value)"
    }

    private func deleteKey(at indexPath: IndexPath) {
        let key = items[indexPath.row].key
        Tools.showAlert(title: "确认删除？", message: key, confirmHandler: { [weak self] in
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.synchronize()
            self?.reloadData()
            JYToast.show("已删除")
        })
    }
}

extension UserDefaultsListVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DebugInfoCell.identifier, for: indexPath) as! DebugInfoCell
        let item = items[indexPath.row]
        cell.textLabel?.text = item.key
        cell.detailTextLabel?.text = previewValue(item.value)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let editVC = UserDefaultsEditVC(key: item.key, value: item.value)
        editVC.onSave = { [weak self] in
            self?.reloadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.deleteKey(at: indexPath)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

private class UserDefaultsEditVC: DYBaseVC {
    private let key: String
    private let originalValue: Any
    private let textView = UITextView()
    var onSave: (() -> Void)?

    init(key: String, value: Any) {
        self.key = key
        self.originalValue = value
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = key
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveValue)),
            navigationItem.rightBarButtonItem
        ].compactMap { $0 }

        textView.font = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13)
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.text = editableText(from: originalValue)
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func editableText(from value: Any) -> String {
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(value)"
    }

    @objc private func saveValue() {
        let text = textView.text ?? ""
        let value: Any
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []),
           JSONSerialization.isValidJSONObject(json) {
            value = json
        } else if let bool = Bool(text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            value = bool
        } else if let int = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            value = int
        } else if let double = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            value = double
        } else {
            value = text
        }

        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
        onSave?()
        JYToast.show("保存成功")
        navigationController?.popViewController(animated: true)
    }
}




extension MainToolVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MainToolCell", for: indexPath)
        let row = indexPath.row
        let model = items[row]
        cell.textLabel?.text = model.title
        cell.imageView?.image = UIImage(inSDK: "icon.png")
        
        let size = CGSize(width: 40, height: 40)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        cell.imageView?.image?.draw(in: CGRect(origin: CGPoint.zero, size: size))
        cell.imageView?.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        
        let model = items[row]
        if responds(to: model.selector) {
            if model.userInfo == nil {
                perform(model.selector)
            } else {
                perform(model.selector, with: model.userInfo)
            }
        }
    }
}
