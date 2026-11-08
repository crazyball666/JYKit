//
//  DYAppInfoVC.swift
//  JYKit
//

import UIKit

private final class DYInfoCell: UITableViewCell {
    static let identifier = "DYInfoCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        textLabel?.font = .systemFont(ofSize: 15)
        detailTextLabel?.font = .systemFont(ofSize: 13)
        detailTextLabel?.textColor = DYStyle.secondaryText
        detailTextLabel?.numberOfLines = 2
        detailTextLabel?.lineBreakMode = .byTruncatingMiddle
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

final class DYAppInfoVC: DYBaseVC {
    private struct Item {
        let title: String
        let value: String
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [(title: String, items: [Item])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "App 现场信息"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(exportInfo)),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadItems))
        ]

        tableView.register(DYInfoCell.self, forCellReuseIdentifier: DYInfoCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reloadItems()
    }

    @objc private func reloadItems() {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]
        let process = ProcessInfo.processInfo

        let appItems = [
            Item(title: "App 名称", value: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? ""),
            Item(title: "Bundle ID", value: bundle.bundleIdentifier ?? ""),
            Item(title: "版本号", value: info["CFBundleShortVersionString"] as? String ?? ""),
            Item(title: "Build", value: info["CFBundleVersion"] as? String ?? ""),
            Item(title: "是否调试中", value: JYDeviceInfo.isBeingDebugged() ? "true" : "false")
        ]

        let deviceItems = [
            Item(title: "设备型号", value: UIDevice.current.dy_displayModel),
            Item(title: "设备平台", value: JYDeviceInfo.platform()),
            Item(title: "系统版本", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"),
            Item(title: "CPU 核心数", value: "\(JYDeviceInfo.cpuCount())"),
            Item(title: "物理内存", value: process.physicalMemory.formattedAsDataSize()),
            Item(title: "进程内存", value: JYDeviceInfo.footprintMemory().formattedAsDataSize()),
            Item(title: "可用内存", value: JYDeviceInfo.availableMemory().formattedAsDataSize())
        ]

        let pathItems = [
            Item(title: "Bundle 路径", value: bundle.bundlePath),
            Item(title: "沙盒路径", value: NSHomeDirectory())
        ]

        sections = [
            ("应用", appItems),
            ("设备", deviceItems),
            ("路径", pathItems)
        ]
        tableView.reloadData()
    }

    @objc private func exportInfo() {
        let text = sections
            .map { section in
                "[\(section.title)]\n" + section.items.map { "\($0.title): \($0.value)" }.joined(separator: "\n")
            }
            .joined(separator: "\n\n")
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activity.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(activity, animated: true)
    }
}

extension DYAppInfoVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DYInfoCell.identifier, for: indexPath) as! DYInfoCell
        let item = sections[indexPath.section].items[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.value
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIPasteboard.general.string = sections[indexPath.section].items[indexPath.row].value
        JYToast.show("已复制")
    }
}
