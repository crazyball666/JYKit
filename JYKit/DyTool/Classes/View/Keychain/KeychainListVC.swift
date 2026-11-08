//
//  KeychainListVC.swift
//  JYKit
//

import UIKit

final class KeychainListVC: DYBaseVC {
    private struct Section {
        let title: String
        let items: [KeychainItem]
    }

    private let cellIdentifier = "KeychainCell"
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [Section] = []
    private var keyword: String = ""

    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "搜索 Key 或内容"
        bar.searchBarStyle = .minimal
        bar.autocapitalizationType = .none
        return bar
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无条目\n点击右上角 + 添加"
        label.textColor = DYStyle.secondaryText
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Keychain"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addItem)
        )
        searchBar.delegate = self
        searchBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
        tableView.tableHeaderView = searchBar
        tableView.register(DYSubtitleCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func loadData() {
        let items = KeychainManager.getAllItems()
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        let filtered = filter(items)
        let grouped = Dictionary(grouping: filtered) { item in
            (item.service?.isEmpty == false) ? item.service! : "默认服务"
        }
        sections = grouped
            .map { Section(title: $0.key, items: $0.value) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        tableView.reloadData()
        emptyLabel.isHidden = !sections.isEmpty
        emptyLabel.text = keyword.isEmpty ? "暂无条目\n点击右上角 + 添加" : "没有匹配的条目"
    }

    private func filter(_ items: [KeychainItem]) -> [KeychainItem] {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return items }
        return items.filter {
            $0.key.localizedCaseInsensitiveContains(text) ||
            previewValue($0).localizedCaseInsensitiveContains(text)
        }
    }

    private func previewValue(_ item: KeychainItem) -> String {
        switch item.type {
        case .string:
            return item.value as? String ?? ""
        case .bool:
            return (item.value as? Bool == true) ? "true" : "false"
        case .int:
            return "\(item.value as? Int ?? 0)"
        case .double:
            return "\(item.value as? Double ?? 0)"
        case .data:
            if let data = item.value as? Data {
                return "\(data.count) bytes"
            }
            return ""
        }
    }

    @objc private func addItem() {
        let editVC = KeychainEditVC(item: nil)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }
}

extension KeychainListVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        keyword = searchText
        loadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension KeychainListVC: UITableViewDataSource, UITableViewDelegate {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as? DYSubtitleCell
            ?? DYSubtitleCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        let item = sections[indexPath.section].items[indexPath.row]
        cell.textLabel?.text = item.key
        cell.detailTextLabel?.text = "\(item.type.rawValue): \(previewValue(item))"
        cell.detailTextLabel?.textColor = DYStyle.secondaryText
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        let editVC = KeychainEditVC(item: item)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = sections[indexPath.section].items[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            Tools.showAlert(title: "确认删除？", message: item.key, confirmHandler: {
                _ = KeychainManager.delete(item: item)
                self?.loadData()
                JYToast.show("已删除")
            })
            completion(true)
        }

        let copyAction = UIContextualAction(style: .normal, title: "复制值") { [weak self] _, _, completion in
            UIPasteboard.general.string = self?.previewValue(item)
            JYToast.show("已复制")
            completion(true)
        }
        copyAction.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [deleteAction, copyAction])
    }
}
