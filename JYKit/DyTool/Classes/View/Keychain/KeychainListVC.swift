//
//  KeychainListVC.swift
//  JYKit
//

import UIKit

class KeychainListVC: DYBaseVC {
    private let cellIdentifier = "KeychainCell"
    private var tableView = UITableView()
    private var items: [KeychainItem] = []
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无条目"
        label.textColor = .gray
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keychain"
        view.backgroundColor = .white

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addItem)
        )

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)

        emptyLabel.frame = view.bounds
        emptyLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(emptyLabel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func loadData() {
        items = KeychainManager.getAllItems()
        tableView.reloadData()
        emptyLabel.isHidden = items.count != 0
    }

    @objc private func addItem() {
        let editVC = KeychainEditVC(item: nil)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }
}

extension KeychainListVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let item = items[indexPath.row]

        cell.textLabel?.text = item.key
        cell.detailTextLabel?.text = "\(item.type.rawValue): \(previewValue(item))"

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let editVC = KeychainEditVC(item: item)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else { return }
            let item = self.items[indexPath.row]
            if KeychainManager.delete(key: item.key) {
                self.items.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
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
                let hex = data.prefix(16).map { String(format: "%02x", $0) }.joined()
                return data.count > 16 ? "\(hex)..." : hex
            }
            return ""
        }
    }
}