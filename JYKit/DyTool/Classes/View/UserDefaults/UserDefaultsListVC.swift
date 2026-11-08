//
//  UserDefaultsListVC.swift
//  JYKit
//

import UIKit

class UserDefaultsListVC: DYBaseVC {
    private enum FilterScope: Int, CaseIterable {
        case all = 0
        case appOnly = 1
        case systemOnly = 2

        var title: String {
            switch self {
            case .all: return "全部"
            case .appOnly: return "App 条目"
            case .systemOnly: return "系统条目"
            }
        }
    }

    private let cellIdentifier = "UserDefaultsCell"
    private var tableView = UITableView(frame: .zero, style: .plain)
    private var allItems: [UserDefaultsItem] = []
    private var filteredItems: [UserDefaultsItem] = []
    private var currentScope: FilterScope = .all
    private var searchKeyword: String = ""

    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "搜索 Key 或内容"
        bar.searchBarStyle = .minimal
        bar.autocapitalizationType = .none
        return bar
    }()

    private lazy var scopeSegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: FilterScope.allCases.map { $0.title })
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(scopeChanged(_:)), for: .valueChanged)
        return segment
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "暂无匹配条目"
        label.textColor = .lightGray
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.isHidden = true
        return label
    }()

    private lazy var countLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40))
        label.textColor = .gray
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UserDefaults"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        setupNav()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupNav() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addItem))
        let moreButton = UIBarButtonItem(title: "更多", style: .plain, target: self, action: #selector(showMoreMenu))
        navigationItem.rightBarButtonItems = [addButton, moreButton]

    }

    private func setupUI() {
        // 顶部筛选分段控件容器
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            headerView.backgroundColor = .secondarySystemBackground
        } else {
            headerView.backgroundColor = UIColor(white: 0.96, alpha: 1.0)
        }
        view.addSubview(headerView)

        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(searchBar)

        scopeSegment.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(scopeSegment)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UserDefaultsCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.estimatedRowHeight = 68
        tableView.rowHeight = UITableView.automaticDimension
        tableView.tableFooterView = countLabel
        view.addSubview(tableView)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: guide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 88),

            searchBar.topAnchor.constraint(equalTo: headerView.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -4),
            searchBar.heightAnchor.constraint(equalToConstant: 44),

            scopeSegment.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            scopeSegment.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            scopeSegment.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -6),
            scopeSegment.heightAnchor.constraint(equalToConstant: 32),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -40)
        ])
    }

    private func loadData() {
        allItems = UserDefaultsManager.getAllItems()
        applyFilter()
    }

    private func applyFilter() {
        var items = allItems

        // 作用域筛选
        switch currentScope {
        case .all:
            break
        case .appOnly:
            items = items.filter { !$0.isSystemKey }
        case .systemOnly:
            items = items.filter { $0.isSystemKey }
        }

        // 关键字搜索
        let keyword = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !keyword.isEmpty {
            items = items.filter { item in
                if item.key.lowercased().contains(keyword) {
                    return true
                }
                let preview = UserDefaultsManager.previewString(for: item.value, type: item.type).lowercased()
                return preview.contains(keyword)
            }
        }

        filteredItems = items
        tableView.reloadData()
        emptyLabel.isHidden = !filteredItems.isEmpty
        countLabel.text = "共 \(filteredItems.count) 条记录（总计 \(allItems.count)）"
    }

    @objc private func scopeChanged(_ sender: UISegmentedControl) {
        guard let scope = FilterScope(rawValue: sender.selectedSegmentIndex) else { return }
        currentScope = scope
        applyFilter()
    }

    @objc private func addItem() {
        let editVC = UserDefaultsEditVC(item: nil)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    @objc private func showMoreMenu() {
        let alert = UIAlertController(title: "操作选项", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "刷新列表", style: .default, handler: { [weak self] _ in
            self?.loadData()
            JYToast.show("已刷新")
        }))

        alert.addAction(UIAlertAction(title: "清空全部业务数据", style: .destructive, handler: { [weak self] _ in
            Tools.showAlert(title: "确定清空全部数据？", message: "将清除 App 写入的 UserDefaults 配置项（系统项会保留），此操作不可逆！", confirmHandler: {
                UserDefaultsManager.clearAll()
                self?.loadData()
                JYToast.show("已清空业务数据")
            })
        }))

        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }

        present(alert, animated: true, completion: nil)
    }
}

// MARK: - 搜索
extension UserDefaultsListVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchKeyword = searchText
        applyFilter()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension UserDefaultsListVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! UserDefaultsCell
        let item = filteredItems[indexPath.row]
        cell.configure(with: item)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        let editVC = UserDefaultsEditVC(item: item)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else { return }
            let item = self.filteredItems[indexPath.row]
            UserDefaultsManager.delete(key: item.key)

            // 从数据源中移除
            self.filteredItems.remove(at: indexPath.row)
            if let allIdx = self.allItems.firstIndex(where: { $0.key == item.key }) {
                self.allItems.remove(at: allIdx)
            }

            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.emptyLabel.isHidden = !self.filteredItems.isEmpty
            self.countLabel.text = "共 \(self.filteredItems.count) 条记录（总计 \(self.allItems.count)）"
            JYToast.show("已删除 \(item.key)")
            completion(true)
        }

        let copyValueAction = UIContextualAction(style: .normal, title: "复制值") { [weak self] _, _, completion in
            guard let self = self else { return }
            let item = self.filteredItems[indexPath.row]
            let preview = UserDefaultsManager.previewString(for: item.value, type: item.type)
            UIPasteboard.general.string = preview
            JYToast.show("已复制值")
            completion(true)
        }
        copyValueAction.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [deleteAction, copyValueAction])
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let copyKeyAction = UIContextualAction(style: .normal, title: "复制 Key") { [weak self] _, _, completion in
            guard let self = self else { return }
            let item = self.filteredItems[indexPath.row]
            UIPasteboard.general.string = item.key
            JYToast.show("已复制 Key")
            completion(true)
        }
        copyKeyAction.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [copyKeyAction])
    }
}

// MARK: - 自定义列表 Cell
private class UserDefaultsCell: UITableViewCell {
    private let keyLabel = UILabel()
    private let typeBadge = UILabel()
    private let tagBadge = UILabel()
    private let previewLabel = UILabel()
    private let topStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator

        keyLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        keyLabel.numberOfLines = 1
        keyLabel.lineBreakMode = .byTruncatingMiddle

        typeBadge.font = .systemFont(ofSize: 10, weight: .bold)
        typeBadge.textAlignment = .center
        typeBadge.layer.cornerRadius = 4
        typeBadge.clipsToBounds = true

        tagBadge.font = .systemFont(ofSize: 10, weight: .medium)
        tagBadge.textAlignment = .center
        tagBadge.layer.cornerRadius = 4
        tagBadge.clipsToBounds = true

        topStack.axis = .horizontal
        topStack.spacing = 6
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false

        topStack.addArrangedSubview(keyLabel)
        topStack.addArrangedSubview(typeBadge)
        topStack.addArrangedSubview(tagBadge)

        previewLabel.font = .systemFont(ofSize: 12)
        previewLabel.textColor = .gray
        previewLabel.numberOfLines = 2
        previewLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(topStack)
        contentView.addSubview(previewLabel)

        // 限制徽标的最小宽度和内边距
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        tagBadge.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            topStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            topStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8),

            typeBadge.heightAnchor.constraint(equalToConstant: 18),
            typeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            tagBadge.heightAnchor.constraint(equalToConstant: 18),
            tagBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 34),

            previewLabel.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 4),
            previewLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with item: UserDefaultsItem) {
        keyLabel.text = item.key
        previewLabel.text = UserDefaultsManager.previewString(for: item.value, type: item.type)

        // 类型徽标样式
        typeBadge.text = item.type.rawValue
        switch item.type {
        case .string:
            typeBadge.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
            typeBadge.textColor = .systemBlue
        case .bool:
            typeBadge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
            typeBadge.textColor = .systemGreen
        case .int, .double:
            typeBadge.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            typeBadge.textColor = .systemOrange
        case .json:
            typeBadge.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.12)
            typeBadge.textColor = .systemPurple
        case .data:
            typeBadge.backgroundColor = UIColor.systemBrown.withAlphaComponent(0.12)
            typeBadge.textColor = .brown
        case .date:
            typeBadge.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.12)
            typeBadge.textColor = .systemTeal
        }

        // 来源标记
        if item.isSystemKey {
            tagBadge.text = "系统"
            tagBadge.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
            tagBadge.textColor = .darkGray
        } else {
            tagBadge.text = "App"
            tagBadge.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12)
            tagBadge.textColor = .systemIndigo
        }
    }
}
