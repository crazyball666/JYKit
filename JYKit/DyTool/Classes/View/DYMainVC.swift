//
//  DYMainVC.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

class DYMainVC: UINavigationController {
    static let shared = DYMainVC(rootViewController: MainToolVC())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DYStyle.background
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            if #available(iOS 15.0, *) {
                navigationBar.compactAppearance = appearance
            }
        } else {
            navigationBar.barTintColor = .white
            navigationBar.isTranslucent = false
        }
    }

    func present(completion: (() -> Void)? = nil) {
        guard let topVC = Tools.rootVC()?.topVC(), topVC != self else {
            completion?()
            return
        }
        if self.isBeingPresented {
            self.dismiss(animated: false) {
                topVC.present(self, animated: true, completion: completion)
            }
            return
        }
        topVC.present(self, animated: true, completion: completion)
    }

    func dismiss() {
        self.dismiss(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setFloatingOverlaysHidden(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            setFloatingOverlaysHidden(false)
        }
    }

    /// 打开工具面板时隐藏悬浮球和悬浮监控，避免遮挡界面；关闭后恢复。
    private func setFloatingOverlaysHidden(_ hidden: Bool) {
        DYFloatingBall.default.isHidden = hidden
        DYMonitorView.shared.isHidden = hidden
    }
}


// MARK: - 工具首页

final class MainToolVC: DYBaseVC {
    private struct ToolRow {
        let title: String
        let subtitle: String
        let symbol: String
        let tint: UIColor
        let handler: () -> Void
        /// 启动参数 `-JYKitTool <keyword>` 使用的标识
        var keyword: String = ""
    }

    private struct ToolSection {
        let title: String
        let rows: [ToolRow]
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [ToolSection] = []
    private var filteredSections: [ToolSection] = []
    private var keyword: String = ""

    private let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "搜索工具"
        bar.searchBarStyle = .minimal
        bar.autocapitalizationType = .none
        return bar
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "没有匹配的工具"
        label.textColor = DYStyle.secondaryText
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private var hasHandledLaunchArgument = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        openToolIfLaunchedWithArgument()
    }

    /// 便于自动化/截图调试：启动参数 `-JYKitTool <name>` 可直接进入某个工具页。
    private func openToolIfLaunchedWithArgument() {
        guard !hasHandledLaunchArgument else { return }
        hasHandledLaunchArgument = true

        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-JYKitTool"), index + 1 < arguments.count else {
            return
        }
        let name = arguments[index + 1].lowercased()

        for section in sections {
            for row in section.rows where row.keyword == name {
                row.handler()
                return
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DyTool"

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(close))

        buildSections()
        filteredSections = sections
        tableView.register(DYToolCell.self, forCellReuseIdentifier: DYToolCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = DYStyle.groupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.keyboardDismissMode = .onDrag
        tableView.tableHeaderView = makeHeaderView()
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
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func buildSections() {
        let performance = ToolSection(title: "性能监控", rows: [
            ToolRow(title: "悬浮监控设置",
                    subtitle: "选择悬浮窗中展示的 FPS、内存、CPU 等指标",
                    symbol: "gauge.with.dots.needle.67percent",
                    tint: .systemOrange,
                    handler: { [weak self] in self?.push(DYMonitorSettingsVC()) },
                    keyword: "monitor"),
            ToolRow(title: "卡顿监控",
                    subtitle: "主线程卡顿检测与调用栈记录",
                    symbol: "waveform.path.ecg",
                    tint: .systemRed,
                    handler: { [weak self] in self?.push(DYLagMonitorVC()) },
                    keyword: "lag")
        ])

        let debugging = ToolSection(title: "调试工具", rows: [
            ToolRow(title: "日志查看",
                    subtitle: "实时查看 print 输出并搜索、导出",
                    symbol: "doc.text.magnifyingglass",
                    tint: .systemBlue,
                    handler: { [weak self] in self?.push(DYLogVC()) },
                    keyword: "logs"),
            ToolRow(title: "UI 层级查看",
                    subtitle: "浏览视图树、点选高亮，并可实时修改属性",
                    symbol: "square.3.layers.3d",
                    tint: .systemPurple,
                    handler: { [weak self] in self?.push(DYUIInspectorVC()) },
                    keyword: "inspector"),
            ToolRow(title: "页面栈",
                    subtitle: "查看当前窗口的控制器层级",
                    symbol: "rectangle.stack",
                    tint: .systemTeal,
                    handler: { [weak self] in self?.push(DYViewControllerStackVC()) },
                    keyword: "vcstack"),
        ])

        let data = ToolSection(title: "数据管理", rows: [
            ToolRow(title: "Keychain 管理",
                    subtitle: "查看、新增、编辑与删除 Keychain 条目",
                    symbol: "key.fill",
                    tint: .systemYellow,
                    handler: { [weak self] in self?.push(KeychainListVC()) },
                    keyword: "keychain"),
            ToolRow(title: "UserDefaults 管理",
                    subtitle: "查看、新增、编辑与删除 UserDefaults 条目",
                    symbol: "externaldrive.fill",
                    tint: .systemIndigo,
                    handler: { [weak self] in self?.push(UserDefaultsListVC()) },
                    keyword: "userdefaults")
        ])

        let files = ToolSection(title: "文件", rows: [
            ToolRow(title: "沙盒文件管理",
                    subtitle: "浏览 App 沙盒目录与文件内容",
                    symbol: "folder.fill",
                    tint: .systemBlue,
                    handler: { [weak self] in
                        self?.push(DirectoryManageVC(path: NSHomeDirectory()))
                    },
                    keyword: "sandbox"),
            ToolRow(title: "包体文件管理",
                    subtitle: "浏览 App Bundle 内的资源文件",
                    symbol: "shippingbox.fill",
                    tint: .systemGray,
                    handler: { [weak self] in
                        self?.push(DirectoryManageVC(path: Bundle.main.bundlePath))
                    },
                    keyword: "bundle")
        ])

        let environment = ToolSection(title: "环境信息", rows: [
            ToolRow(title: "App 现场信息",
                    subtitle: "版本、设备、内存等运行时信息",
                    symbol: "info.circle.fill",
                    tint: .systemBlue,
                    handler: { [weak self] in self?.push(DYAppInfoVC()) },
                    keyword: "appinfo"),
            ToolRow(title: "启动参数",
                    subtitle: "ProcessInfo 中的 arguments 与环境变量",
                    symbol: "terminal.fill",
                    tint: .systemGray,
                    handler: { [weak self] in self?.showProcessInfo() },
                    keyword: "processinfo"),
            ToolRow(title: "释放内存",
                    subtitle: "归还空闲内存并广播内存警告",
                    symbol: "memorychip.fill",
                    tint: .systemPink,
                    handler: { [weak self] in self?.releaseMemory() },
                    keyword: "memory")
        ])

        sections = [performance, debugging, data, files, environment]
    }

    private func makeHeaderView() -> UIView {
        let info = Bundle.main.infoDictionary ?? [:]
        let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "App"
        let version = info["CFBundleShortVersionString"] as? String ?? "-"
        let build = info["CFBundleVersion"] as? String ?? "-"

        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        container.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = "\(name)  v\(version) (\(build))"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = DYStyle.text

        let detailLabel = UILabel()
        detailLabel.text = "\(UIDevice.current.dy_displayModel)  ·  iOS \(UIDevice.current.systemVersion)"
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = DYStyle.secondaryText

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 2

        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(infoStack)
        container.addSubview(searchBar)

        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            infoStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),

            searchBar.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            searchBar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }

    private func push(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func showProcessInfo() {
        let process = ProcessInfo.processInfo
        var lines: [String] = []
        lines.append("arguments:")
        lines.append(process.arguments.isEmpty ? "  (空)" : process.arguments.map { "  \($0)" }.joined(separator: "\n"))
        lines.append("")
        lines.append("environment:")
        let environment = process.environment.sorted { $0.key < $1.key }
        lines.append(environment.isEmpty ? "  (空)" : environment.map { "  \($0.key) = \($0.value)" }.joined(separator: "\n"))
        lines.append("")
        lines.append("进程:")
        lines.append("  PID: \(process.processIdentifier)")
        lines.append("  名称: \(process.processName)")
        lines.append("  处理器数: \(process.processorCount)")
        lines.append("  活跃处理器: \(process.activeProcessorCount)")
        lines.append("  系统运行时长: \(Int(process.systemUptime))s")
        push(DYTextVC(title: "启动参数", content: lines.joined(separator: "\n")))
    }

    private func releaseMemory() {
        let freed = malloc_zone_pressure_relief(nil, 0)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        JYToast.show("已释放 \(freed.formattedAsDataSize())")
    }
}

// MARK: - 搜索
extension MainToolVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            filteredSections = sections
            emptyLabel.isHidden = true
            tableView.reloadData()
            return
        }

        filteredSections = sections.compactMap { section in
            let rows = section.rows.filter {
                $0.title.localizedCaseInsensitiveContains(keyword) ||
                $0.subtitle.localizedCaseInsensitiveContains(keyword)
            }
            return rows.isEmpty ? nil : ToolSection(title: section.title, rows: rows)
        }
        emptyLabel.isHidden = !filteredSections.isEmpty
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - TableView
extension MainToolVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredSections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return filteredSections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DYToolCell.identifier, for: indexPath) as! DYToolCell
        let row = filteredSections[indexPath.section].rows[indexPath.row]
        cell.configure(title: row.title, subtitle: row.subtitle, symbol: row.symbol, tint: row.tint)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        filteredSections[indexPath.section].rows[indexPath.row].handler()
    }
}

// MARK: - 工具 Cell

final class DYToolCell: UITableViewCell {
    static let identifier = "DYToolCell"

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let textStack = UIStackView()

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

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = 8
        contentView.addSubview(iconContainer)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = DYStyle.text
        titleLabel.numberOfLines = 1

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = DYStyle.secondaryText
        subtitleLabel.numberOfLines = 2

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(title: String, subtitle: String, symbol: String, tint: UIColor) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconContainer.backgroundColor = DYStyle.tintedBackground(tint)
        if #available(iOS 13.0, *) {
            iconView.image = UIImage(systemName: symbol)
        } else {
            iconView.image = UIImage(inSDK: "icon.png")
        }
        iconView.tintColor = tint
    }
}
