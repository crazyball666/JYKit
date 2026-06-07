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
    let detailItems: [DYDetailItem]

    init(view: UIView, path: String, depth: Int) {
        self.view = view
        self.title = String(describing: type(of: view))
        self.path = path
        self.depth = depth
        self.subtitle = "frame: \(DYUIInspectorFormatter.rect(view.frame))  subviews: \(view.subviews.count)"
        self.detailItems = DYUIInspectorSnapshot.makeDetailItems(view: view, path: path)
    }
}

final class DYUIInspectorNode {
    let snapshot: DYUIInspectorSnapshot
    let children: [DYUIInspectorNode]

    init(snapshot: DYUIInspectorSnapshot, children: [DYUIInspectorNode]) {
        self.snapshot = snapshot
        self.children = children
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
    private static func makeDetailItems(view: UIView, path: String) -> [DYDetailItem] {
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
        let snapshot = DYUIInspectorSnapshot(view: view, path: path, depth: depth)
        let children = view.subviews.enumerated().map { index, child -> DYUIInspectorNode in
            let childTitle = "\(String(describing: type(of: child)))[\(index)]"
            return makeNode(view: child, path: "\(path) > \(childTitle)", depth: depth + 1)
        }
        return DYUIInspectorNode(snapshot: snapshot, children: children)
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
        return allWindows.filter { $0 !== DYFMainWindow.shared }
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
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        reloadTree()
    }

    @objc private func reloadTree() {
        let nextNodes = DYUIInspectorBuilder.rootNodes()
        if hasLoadedTree {
            expandedPaths = expandedPaths.intersection(allPaths(in: nextNodes))
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

    private func allPaths(in nodes: [DYUIInspectorNode]) -> Set<String> {
        var paths: Set<String> = []
        nodes.forEach { collectPaths(from: $0, into: &paths) }
        return paths
    }

    private func collectPaths(from node: DYUIInspectorNode, into paths: inout Set<String>) {
        paths.insert(node.snapshot.path)
        node.children.forEach { collectPaths(from: $0, into: &paths) }
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
        let isBranch = !node.children.isEmpty
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
        if node.children.isEmpty {
            showDetail(for: node)
        } else {
            toggleNode(node)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        showDetail(for: flattenedNodes[indexPath.row])
    }
}

final class DYUIInspectorDetailVC: DYBaseVC {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let snapshot: DYUIInspectorSnapshot

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
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func highlightView() {
        guard let targetView = snapshot.view, let window = targetView.window else {
            JYToast.show("目标已释放")
            return
        }
        DYUIInspectorHighlightView.show(targetView, in: window)
    }
}

extension DYUIInspectorDetailVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshot.detailItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
        DYUIInspectorHighlightView.show(target, in: window)
        removeFromSuperview()
        completion?(target)
    }
}

final class DYUIInspectorHighlightView: UIView {
    static func show(_ targetView: UIView, in window: UIWindow) {
        let rect = targetView.convert(targetView.bounds, to: window)
        let highlight = DYUIInspectorHighlightView(frame: rect.insetBy(dx: -1, dy: -1))
        window.addSubview(highlight)
        UIView.animate(withDuration: 0.2, delay: 1.2, options: []) {
            highlight.alpha = 0
        } completion: { _ in
            highlight.removeFromSuperview()
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
