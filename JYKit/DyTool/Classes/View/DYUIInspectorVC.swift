//
//  DYUIInspectorVC.swift
//  JYKit
//
//  Created by Codex on 2026/6/7.
//

import UIKit

struct DYDetailItem {
    let title: String
    let value: String
}

final class DYUIInspectorSnapshot {
    weak var view: UIView?
    let title: String
    let subtitle: String
    let path: String
    let depth: Int
    /// 详情项按需生成：完整视图树里每个视图都生成一遍代价很高。
    private var cachedDetailItems: [DYDetailItem]?

    var detailItems: [DYDetailItem] {
        if let cached = cachedDetailItems {
            return cached
        }
        let items = DYUIInspectorSnapshot.makeDetailItems(view: view, path: path)
        cachedDetailItems = items
        return items
    }

    init(view: UIView, path: String, depth: Int) {
        self.view = view
        self.title = String(describing: type(of: view))
        self.path = path
        self.depth = depth
        self.subtitle = "frame: \(DYUIInspectorFormatter.rect(view.frame))  subviews: \(view.subviews.count)"
    }

    /// 属性被实时修改后，丢弃缓存重新生成
    func invalidateDetails() {
        cachedDetailItems = nil
    }
}

final class DYUIInspectorNode {
    let snapshot: DYUIInspectorSnapshot
    private weak var view: UIView?
    /// 子节点只在展开时构建，避免一次性递归整棵视图树。
    private lazy var builtChildren: [DYUIInspectorNode] = {
        guard let view = view else { return [] }
        return view.subviews.enumerated().map { index, child in
            let childTitle = "\(String(describing: type(of: child)))[\(index)]"
            return DYUIInspectorNode(view: child, path: "\(snapshot.path) > \(childTitle)", depth: snapshot.depth + 1)
        }
    }()

    var children: [DYUIInspectorNode] {
        return builtChildren
    }

    var hasChildren: Bool {
        return !(view?.subviews.isEmpty ?? true)
    }

    init(view: UIView, path: String, depth: Int) {
        self.view = view
        self.snapshot = DYUIInspectorSnapshot(view: view, path: path, depth: depth)
    }
}

enum DYUIInspectorFormatter {
    static func rect(_ rect: CGRect) -> String {
        return "(\(number(rect.origin.x)), \(number(rect.origin.y)), \(number(rect.size.width)), \(number(rect.size.height)))"
    }

    static func point(_ point: CGPoint) -> String {
        return "(\(number(point.x)), \(number(point.y)))"
    }

    static func size(_ size: CGSize) -> String {
        return "(\(number(size.width)), \(number(size.height)))"
    }

    static func color(_ color: UIColor?) -> String {
        guard let color = color else {
            return "nil"
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return "rgba(\(number(red * 255)), \(number(green * 255)), \(number(blue * 255)), \(number(alpha)))"
        }
        return "\(color)"
    }

    static func number(_ value: CGFloat) -> String {
        return String(format: "%.1f", Double(value))
    }
}

extension DYUIInspectorSnapshot {
    fileprivate static func makeDetailItems(view: UIView?, path: String) -> [DYDetailItem] {
        guard let view = view else {
            return [DYDetailItem(title: "view", value: "已释放")]
        }
        var items: [DYDetailItem] = [
            DYDetailItem(title: "class", value: String(describing: type(of: view))),
            DYDetailItem(title: "path", value: path),
            DYDetailItem(title: "frame", value: DYUIInspectorFormatter.rect(view.frame)),
            DYDetailItem(title: "bounds", value: DYUIInspectorFormatter.rect(view.bounds)),
            DYDetailItem(title: "center", value: DYUIInspectorFormatter.point(view.center)),
            DYDetailItem(title: "alpha", value: String(format: "%.2f", view.alpha)),
            DYDetailItem(title: "hidden", value: "\(view.isHidden)"),
            DYDetailItem(title: "userInteraction", value: "\(view.isUserInteractionEnabled)"),
            DYDetailItem(title: "clipsToBounds", value: "\(view.clipsToBounds)"),
            DYDetailItem(title: "tag", value: "\(view.tag)"),
            DYDetailItem(title: "backgroundColor", value: DYUIInspectorFormatter.color(view.backgroundColor)),
            DYDetailItem(title: "accessibilityIdentifier", value: view.accessibilityIdentifier ?? "nil"),
            DYDetailItem(title: "subviews", value: "\(view.subviews.count)")
        ]

        if let controller = view.nearestViewController {
            items.append(DYDetailItem(title: "viewController", value: String(describing: type(of: controller))))
        }

        if let gestures = view.gestureRecognizers, !gestures.isEmpty {
            items.append(DYDetailItem(title: "gestures", value: gestures.map { String(describing: type(of: $0)) }.joined(separator: "\n")))
        }

        if !view.constraints.isEmpty {
            let text = view.constraints.prefix(12).map { $0.description }.joined(separator: "\n")
            items.append(DYDetailItem(title: "constraints", value: text))
        }

        return items
    }
}

private extension UIView {
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller
            }
            responder = current.next
        }
        return nil
    }
}

enum DYUIInspectorBuilder {
    static func rootNodes() -> [DYUIInspectorNode] {
        return windows().enumerated().map { index, window in
            let title = "\(String(describing: type(of: window)))[\(index)]"
            return makeNode(view: window, path: title, depth: 0)
        }
    }

    static func snapshot(for view: UIView) -> DYUIInspectorSnapshot {
        return DYUIInspectorSnapshot(view: view, path: path(for: view), depth: 0)
    }

    static func path(for view: UIView) -> String {
        var parts: [String] = []
        var current: UIView? = view
        while let item = current {
            parts.insert(String(describing: type(of: item)), at: 0)
            current = item.superview
        }
        return parts.joined(separator: " > ")
    }

    private static func makeNode(view: UIView, path: String, depth: Int) -> DYUIInspectorNode {
        return DYUIInspectorNode(view: view, path: path, depth: depth)
    }

    private static func windows() -> [UIWindow] {
        let allWindows: [UIWindow]
        if #available(iOS 13.0, *) {
            allWindows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
        } else {
            allWindows = UIApplication.shared.windows
        }
        return allWindows.filter { $0 !== DYMainWindow.shared }
    }
}

final class DYUIInspectorVC: DYBaseVC {
    private let cellIdentifier = "DYUIInspectorCell"
    private let tableView = UITableView()
    private var nodes: [DYUIInspectorNode] = []
    private var flattenedNodes: [DYUIInspectorNode] = []
    private var expandedPaths: Set<String> = []
    private var hasLoadedTree = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "UI层级查看"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "点选", style: .done, target: self, action: #selector(startPicking)),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadTree))
        ]

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 58
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从详情页编辑完返回时，刷新视图树的 frame / 层级展示
        reloadTree()
    }

    @objc private func reloadTree() {
        let nextNodes = DYUIInspectorBuilder.rootNodes()
        if hasLoadedTree {
            expandedPaths = prunedExpandedPaths(in: nextNodes)
        } else {
            expandedPaths = Set(nextNodes.map { $0.snapshot.path })
            hasLoadedTree = true
        }
        nodes = nextNodes
        rebuildFlattenedNodes()
        tableView.reloadData()
    }

    @objc private func startPicking() {
        navigationController?.dismiss(animated: false) {
            DYUIInspectorPickerOverlay.present { view in
                DYMainVC.shared.present()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let snapshot = DYUIInspectorBuilder.snapshot(for: view)
                    DYMainVC.shared.pushViewController(DYUIInspectorDetailVC(snapshot: snapshot), animated: true)
                }
            }
        }
    }

    private func rebuildFlattenedNodes() {
        flattenedNodes = []
        nodes.forEach { appendVisibleNode($0) }
    }

    private func appendVisibleNode(_ node: DYUIInspectorNode) {
        flattenedNodes.append(node)
        guard expandedPaths.contains(node.snapshot.path) else {
            return
        }
        node.children.forEach { appendVisibleNode($0) }
    }

    /// 只沿着「已展开」的分支做校验，不会触发整棵树构建。
    private func prunedExpandedPaths(in nodes: [DYUIInspectorNode]) -> Set<String> {
        var valid: Set<String> = []
        nodes.forEach { collectExpandedPaths(from: $0, into: &valid) }
        return valid.intersection(expandedPaths).union(nodes.map { $0.snapshot.path })
    }

    private func collectExpandedPaths(from node: DYUIInspectorNode, into paths: inout Set<String>) {
        paths.insert(node.snapshot.path)
        guard expandedPaths.contains(node.snapshot.path) else { return }
        node.children.forEach { collectExpandedPaths(from: $0, into: &paths) }
    }

    private func toggleNode(_ node: DYUIInspectorNode) {
        if expandedPaths.contains(node.snapshot.path) {
            expandedPaths.remove(node.snapshot.path)
        } else {
            expandedPaths.insert(node.snapshot.path)
        }
        rebuildFlattenedNodes()
        tableView.reloadData()
    }

    private func showDetail(for node: DYUIInspectorNode) {
        navigationController?.pushViewController(DYUIInspectorDetailVC(snapshot: node.snapshot), animated: true)
    }
}

extension DYUIInspectorVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flattenedNodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) ??
            UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        let node = flattenedNodes[indexPath.row]
        let snapshot = node.snapshot
        let isBranch = node.hasChildren
        let isExpanded = expandedPaths.contains(snapshot.path)
        cell.indentationLevel = min(snapshot.depth, 8)
        cell.indentationWidth = 14
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cell.textLabel?.text = "\(isBranch ? (isExpanded ? "[-]" : "[+]") : "   ") \(snapshot.title)"
        cell.detailTextLabel?.font = .systemFont(ofSize: 11)
        cell.detailTextLabel?.textColor = .gray
        cell.detailTextLabel?.text = snapshot.subtitle
        cell.accessoryView = nil
        cell.accessoryType = isBranch ? .detailButton : .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let node = flattenedNodes[indexPath.row]
        if node.hasChildren {
            toggleNode(node)
        } else {
            showDetail(for: node)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        showDetail(for: flattenedNodes[indexPath.row])
    }
}

/// 「可见」开关专用 Cell：每个 Cell 持有自己的 UISwitch。
/// 之前共用一个 UISwitch 并在开关事件里同步 reload，会让 UIKit 在移除当前
/// Cell 的 accessoryView 时重入布局，表现为界面卡死。
private final class DYVisibilityCell: UITableViewCell {
    static let identifier = "DYUIInspectorVisibilityCell"

    let toggle = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.text = "可见"
        textLabel?.font = .systemFont(ofSize: 14)
        selectionStyle = .none
        accessoryView = toggle
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DYUIInspectorDetailVC: DYBaseVC {
    private enum Section: Int, CaseIterable {
        case edit
        case detail
    }

    private struct EditRow {
        let title: String
        let value: () -> String
        let handler: () -> Void
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let snapshot: DYUIInspectorSnapshot
    private var editRows: [EditRow] = []

    init(snapshot: DYUIInspectorSnapshot) {
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = snapshot.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "高亮", style: .done, target: self, action: #selector(highlightView))

        buildEditRows()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DYVisibilityCell.self, forCellReuseIdentifier: DYVisibilityCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.keyboardDismissMode = .onDrag
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - 编辑项

    private func buildEditRows() {
        guard let view = snapshot.view else {
            editRows = []
            return
        }

        var rows: [EditRow] = [
            EditRow(title: "透明度",
                    value: { [weak self] in
                        guard let target = self?.snapshot.view else { return "-" }
                        return String(format: "%.2f", target.alpha)
                    },
                    handler: { [weak self] in self?.editAlpha() }),
            EditRow(title: "背景色",
                    value: { [weak self] in
                        DYUIInspectorFormatter.color(self?.snapshot.view?.backgroundColor)
                    },
                    handler: { [weak self] in self?.editBackgroundColor() }),
            EditRow(title: "Frame",
                    value: { [weak self] in
                        guard let frame = self?.snapshot.view?.frame else { return "-" }
                        return DYUIInspectorFormatter.rect(frame)
                    },
                    handler: { [weak self] in self?.editFrame() }),
            EditRow(title: "圆角",
                    value: { [weak self] in
                        guard let radius = self?.snapshot.view?.layer.cornerRadius else { return "-" }
                        return String(format: "%.1f", radius)
                    },
                    handler: { [weak self] in self?.editCornerRadius() }),
            EditRow(title: "置于最上层",
                    value: { "点击执行" },
                    handler: { [weak self] in self?.bringToFront() })
        ]

        if textContent(of: view) != nil {
            rows.insert(EditRow(title: "文本",
                                value: { [weak self] in
                                    guard let target = self?.snapshot.view,
                                          let text = self?.textContent(of: target) else {
                                        return "-"
                                    }
                                    let single = text.replacingOccurrences(of: "\n", with: "⏎")
                                    return single.count > 24 ? String(single.prefix(24)) + "…" : single
                                },
                                handler: { [weak self] in self?.editText() }),
                       at: 3)
        }

        editRows = rows
    }

    private func targetView() -> UIView? {
        guard let view = snapshot.view else {
            JYToast.show("目标视图已释放")
            return nil
        }
        return view
    }

    /// 编辑生效后刷新详情数据
    private func applyChange() {
        snapshot.invalidateDetails()
        tableView.reloadSections(IndexSet(integersIn: 0..<Section.allCases.count), with: .none)
    }

    /// 目标视图是否就是调试面板本身或它的祖先。
    /// 对这类视图做隐藏 / 全透明，会让工具甚至整个 App 的界面直接消失，看起来就像卡死。
    private func isToolHostingView(_ target: UIView) -> Bool {
        if target is UIWindow {
            return true
        }
        guard let ownView = viewIfLoaded else {
            return false
        }
        return target === ownView || ownView.isDescendant(of: target)
    }

    @objc private func onVisibilityChanged(_ sender: UISwitch) {
        guard let target = targetView() else {
            sender.isOn = true
            return
        }
        if !sender.isOn && isToolHostingView(target) {
            sender.setOn(true, animated: true)
            JYToast.show("该视图包含调试面板，不能隐藏")
            return
        }

        target.isHidden = !sender.isOn
        // 不在开关自身的事件回调里同步刷新 tableView，否则 UIKit 会在移除当前
        // Cell（及其 accessoryView）时重入布局，导致界面卡死。
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.snapshot.invalidateDetails()
            self.tableView.reloadSections(IndexSet(integer: Section.detail.rawValue), with: .none)
        }
    }

    private func editAlpha() {
        guard let view = targetView() else { return }
        let alert = UIAlertController(title: "透明度", message: "取值范围 0 ~ 1", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.text = String(format: "%.2f", view.alpha)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text,
                  let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                JYToast.show("请输入 0 ~ 1 之间的数字")
                return
            }
            let alpha = CGFloat(min(max(value, 0), 1))
            if alpha == 0, self?.isToolHostingView(view) == true {
                JYToast.show("该视图包含调试面板，不能设为全透明")
                return
            }
            view.alpha = alpha
            self?.applyChange()
        }))
        present(alert, animated: true)
    }

    private func editBackgroundColor() {
        guard let view = targetView() else { return }
        if #available(iOS 14.0, *) {
            let picker = UIColorPickerViewController()
            picker.delegate = self
            picker.supportsAlpha = true
            picker.selectedColor = view.backgroundColor ?? .clear
            present(picker, animated: true)
            return
        }

        let colors: [(String, UIColor)] = [
            ("白色", .white), ("黑色", .black), ("红色", .red),
            ("绿色", .green), ("蓝色", .blue), ("透明", .clear)
        ]
        let sheet = UIAlertController(title: "背景色", message: nil, preferredStyle: .actionSheet)
        colors.forEach { name, color in
            sheet.addAction(UIAlertAction(title: name, style: .default, handler: { [weak self] _ in
                view.backgroundColor = color
                self?.applyChange()
            }))
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
        }
        present(sheet, animated: true)
    }

    private func editFrame() {
        guard let view = targetView() else { return }
        let alert = UIAlertController(title: "Frame", message: "x / y / width / height", preferredStyle: .alert)
        let values = [view.frame.origin.x, view.frame.origin.y, view.frame.size.width, view.frame.size.height]
        values.forEach { value in
            alert.addTextField { field in
                field.keyboardType = .numbersAndPunctuation
                field.text = String(format: "%.1f", value)
            }
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self, weak alert] _ in
            let numbers = alert?.textFields?.compactMap {
                Double($0.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            } ?? []
            guard numbers.count == 4 else {
                JYToast.show("请输入 4 个有效数字")
                return
            }
            view.frame = CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
            self?.applyChange()
        }))
        present(alert, animated: true)
    }

    private func editCornerRadius() {
        guard let view = targetView() else { return }
        let alert = UIAlertController(title: "圆角", message: "单位 pt", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.text = String(format: "%.1f", view.layer.cornerRadius)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text,
                  let radius = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  radius >= 0 else {
                JYToast.show("请输入有效的圆角值")
                return
            }
            view.layer.cornerRadius = CGFloat(radius)
            view.layer.masksToBounds = radius > 0
            self?.applyChange()
        }))
        present(alert, animated: true)
    }

    private func editText() {
        guard let view = targetView(), let current = textContent(of: view) else { return }
        let alert = UIAlertController(title: "文本", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = current
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            let text = alert.textFields?.first?.text ?? ""
            self?.applyText(text, to: view)
            self?.applyChange()
        }))
        present(alert, animated: true)
    }

    private func bringToFront() {
        guard let view = targetView() else { return }
        view.superview?.bringSubviewToFront(view)
        applyChange()
        JYToast.show("已置于最上层")
    }

    private func textContent(of view: UIView) -> String? {
        if let label = view as? UILabel { return label.text }
        if let field = view as? UITextField { return field.text }
        if let textView = view as? UITextView { return textView.text }
        if let button = view as? UIButton { return button.title(for: .normal) }
        return nil
    }

    private func applyText(_ text: String, to view: UIView) {
        if let label = view as? UILabel {
            label.text = text
        } else if let field = view as? UITextField {
            field.text = text
        } else if let textView = view as? UITextView {
            textView.text = text
        } else if let button = view as? UIButton {
            button.setTitle(text, for: .normal)
        }
    }

    @objc private func highlightView() {
        guard let targetView = snapshot.view, let window = targetView.window else {
            JYToast.show("目标已释放")
            return
        }

        // 调试面板是全屏的，会盖住被高亮的视图，仅靠透明度无法完全隐藏
        // （present 的系统容器仍会留下白色底板）。这里先整体收起面板，
        // 在宿主界面上闪烁高亮，结束后重新打开并回到当前详情页。
        let mainVC = DYMainVC.shared
        let detailSnapshot = snapshot
        mainVC.dismiss(animated: true) {
            DYUIInspectorHighlightView.show(targetView, in: window) {
                mainVC.present {
                    guard !(mainVC.topViewController is DYUIInspectorDetailVC) else {
                        return
                    }
                    if let inspector = mainVC.viewControllers.first(where: { $0 is DYUIInspectorVC }) {
                        mainVC.popToViewController(inspector, animated: false)
                    }
                    mainVC.pushViewController(DYUIInspectorDetailVC(snapshot: detailSnapshot), animated: false)
                }
            }
        }
    }
}

@available(iOS 14.0, *)
extension DYUIInspectorDetailVC: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        snapshot.view?.backgroundColor = viewController.selectedColor
        applyChange()
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        applyChange()
    }
}

extension DYUIInspectorDetailVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .edit:
            return editRows.isEmpty ? 0 : editRows.count + 1
        case .detail:
            return snapshot.detailItems.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .edit:
            return "实时编辑"
        case .detail:
            return "属性"
        case .none:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard Section(rawValue: section) == .edit else { return nil }
        return "修改会立即作用于当前视图，仅本次运行有效"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        if section == .edit {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: DYVisibilityCell.identifier, for: indexPath) as! DYVisibilityCell
                cell.toggle.removeTarget(nil, action: nil, for: .valueChanged)
                cell.toggle.isOn = !(snapshot.view?.isHidden ?? false)
                cell.toggle.isEnabled = snapshot.view != nil
                cell.toggle.addTarget(self, action: #selector(onVisibilityChanged(_:)), for: .valueChanged)
                return cell
            }

            let row = editRows[indexPath.row - 1]
            let cell = tableView.dequeueReusableCell(withIdentifier: "DYUIInspectorEditCell")
                ?? UITableViewCell(style: .value1, reuseIdentifier: "DYUIInspectorEditCell")
            cell.textLabel?.text = row.title
            cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            cell.detailTextLabel?.text = row.value()
            cell.detailTextLabel?.font = UIFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11)
            cell.detailTextLabel?.textColor = DYStyle.secondaryText
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell
        }

        let cellIdentifier = "DYUIInspectorDetailCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) ??
            UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        let item = snapshot.detailItems[indexPath.row]
        cell.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.font = UIFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11)
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = .gray
        cell.detailTextLabel?.text = item.value
        cell.accessoryType = .none
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        if section == .edit {
            guard indexPath.row > 0, editRows.indices.contains(indexPath.row - 1) else { return }
            editRows[indexPath.row - 1].handler()
            return
        }

        UIPasteboard.general.string = snapshot.detailItems[indexPath.row].value
        JYToast.show("已复制")
    }
}

final class DYUIInspectorPickerOverlay: UIView {
    private var completion: ((UIView) -> Void)?
    private weak var targetWindow: UIWindow?
    private let tipLabel = UILabel()

    static func present(completion: @escaping (UIView) -> Void) {
        guard let window = UIApplication.shared.currentKeyWindow else {
            JYToast.show("未找到可点选窗口")
            return
        }
        let overlay = DYUIInspectorPickerOverlay(frame: window.bounds)
        overlay.targetWindow = window
        overlay.completion = completion
        window.addSubview(overlay)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.08)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        tipLabel.text = "点选一个 View"
        tipLabel.textColor = .white
        tipLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        tipLabel.textAlignment = .center
        tipLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        tipLabel.layer.cornerRadius = 8
        tipLabel.clipsToBounds = true
        addSubview(tipLabel)
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tipLabel.topAnchor.constraint(equalTo: topAnchor, constant: 54),
            tipLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            tipLabel.widthAnchor.constraint(equalToConstant: 140),
            tipLabel.heightAnchor.constraint(equalToConstant: 36)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func onTap(_ recognizer: UITapGestureRecognizer) {
        guard let window = targetWindow else {
            removeFromSuperview()
            return
        }

        let point = recognizer.location(in: window)
        isHidden = true
        let target = window.hitTest(point, with: nil) ?? window
        isHidden = false
        removeFromSuperview()
        // 等高亮闪烁结束再打开面板，否则面板会立刻把高亮盖住
        DYUIInspectorHighlightView.show(target, in: window) { [weak self] in
            self?.completion?(target)
        }
    }
}

final class DYUIInspectorHighlightView: UIView {
    static func show(_ targetView: UIView,
                     in window: UIWindow,
                     duration: TimeInterval = 1.6,
                     completion: (() -> Void)? = nil) {
        let rect = targetView.convert(targetView.bounds, to: window)
        let highlight = DYUIInspectorHighlightView(frame: rect.insetBy(dx: -1, dy: -1))
        window.addSubview(highlight)
        window.bringSubviewToFront(highlight)

        // 闪烁两下，便于在复杂界面上定位
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: []) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.25) {
                highlight.alpha = 0.25
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                highlight.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
                highlight.alpha = 0.25
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                highlight.alpha = 1
            }
        } completion: { _ in
            UIView.animate(withDuration: 0.25) {
                highlight.alpha = 0
            } completion: { _ in
                highlight.removeFromSuperview()
                completion?()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.red.withAlphaComponent(0.12)
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 2
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
