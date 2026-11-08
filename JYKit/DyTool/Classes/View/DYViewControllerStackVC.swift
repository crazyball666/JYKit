//
//  DYViewControllerStackVC.swift
//  JYKit
//

import UIKit

final class DYViewControllerStackVC: DYBaseVC {
    private struct Entry {
        let title: String
        let subtitle: String
        let indent: Int
    }

    private let cellIdentifier = "DYVCStackCell"
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [(title: String, entries: [Entry])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "页面栈"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "复制", style: .done, target: self, action: #selector(copyAll)),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadData))
        ]

        tableView.register(DYSubtitleCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reloadData()
    }

    @objc private func reloadData() {
        sections = []
        for (index, window) in allWindows().enumerated() {
            var entries: [Entry] = []
            let windowTitle = "\(type(of: window))"
            entries.append(Entry(
                title: "Window \(index)",
                subtitle: "level: \(window.windowLevel)  hidden: \(window.isHidden)  key: \(window.isKeyWindow)",
                indent: 0
            ))
            if let root = window.rootViewController {
                appendController(root, indent: 1, into: &entries)
            } else {
                entries.append(Entry(title: "rootViewController: nil", subtitle: "", indent: 1))
            }
            sections.append((windowTitle, entries))
        }
        tableView.reloadData()
    }

    private func appendController(_ controller: UIViewController, indent: Int, into entries: inout [Entry]) {
        entries.append(Entry(
            title: controllerTitle(controller),
            subtitle: controllerSubtitle(controller),
            indent: indent
        ))

        if let navigation = controller as? UINavigationController {
            for child in navigation.viewControllers {
                appendController(child, indent: indent + 1, into: &entries)
            }
        } else if let tab = controller as? UITabBarController {
            for child in tab.viewControllers ?? [] {
                appendController(child, indent: indent + 1, into: &entries)
            }
        } else if let split = controller as? UISplitViewController {
            for child in split.viewControllers {
                appendController(child, indent: indent + 1, into: &entries)
            }
        } else if let page = controller as? UIPageViewController,
                  let child = page.viewControllers?.first {
            appendController(child, indent: indent + 1, into: &entries)
        }

        if let presented = controller.presentedViewController {
            entries.append(Entry(title: "presented ↓", subtitle: "", indent: indent))
            appendController(presented, indent: indent + 1, into: &entries)
        }
    }

    private func controllerTitle(_ controller: UIViewController) -> String {
        let name = String(describing: type(of: controller))
        if let nav = controller as? UINavigationController, let top = nav.topViewController {
            return "\(name) → \(String(describing: type(of: top)))"
        }
        return name
    }

    private func controllerSubtitle(_ controller: UIViewController) -> String {
        var parts: [String] = []
        if let title = controller.title, !title.isEmpty {
            parts.append(title)
        }
        if controller.isViewLoaded {
            let size = controller.view.bounds.size
            parts.append("size: \(Int(size.width))×\(Int(size.height))")
        } else {
            parts.append("view 未加载")
        }
        if let nav = controller as? UINavigationController {
            parts.append("stack: \(nav.viewControllers.count)")
        }
        if let tab = controller as? UITabBarController {
            parts.append("selectedIndex: \(tab.selectedIndex)")
        }
        return parts.joined(separator: "  ·  ")
    }

    private func allWindows() -> [UIWindow] {
        let windows: [UIWindow]
        if #available(iOS 13.0, *) {
            windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
                .flatMap { $0.windows }
        } else {
            windows = UIApplication.shared.windows
        }
        return windows.filter { $0 !== DYMainWindow.shared }
    }

    private func plainText() -> String {
        return sections.map { section in
            var lines = ["[\(section.title)]"]
            for entry in section.entries {
                let indent = String(repeating: "  ", count: entry.indent)
                lines.append("\(indent)\(entry.title)  \(entry.subtitle)")
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    @objc private func copyAll() {
        UIPasteboard.general.string = plainText()
        JYToast.show("已复制")
    }
}

extension DYViewControllerStackVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].entries.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as? DYSubtitleCell
            ?? DYSubtitleCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        let entry = sections[indexPath.section].entries[indexPath.row]
        cell.indentationLevel = min(entry.indent, 6)
        cell.indentationWidth = 14
        cell.textLabel?.text = entry.title
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = entry.subtitle
        cell.detailTextLabel?.font = .systemFont(ofSize: 11)
        cell.detailTextLabel?.textColor = DYStyle.secondaryText
        cell.detailTextLabel?.numberOfLines = 2
        cell.selectionStyle = .none
        return cell
    }
}
