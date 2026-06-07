//
//  DYLagMonitorVC.swift
//  JYKit
//
//  Created by Codex on 2026/6/7.
//

import UIKit

struct DYLagRecord {
    let date: Date
    let duration: TimeInterval
    let activity: String
    let callStack: [String]
    let appCPUUsage: Float
    let footprintMemory: UInt64

    init(date: Date = Date(),
         duration: TimeInterval,
         activity: String,
         callStack: [String],
         appCPUUsage: Float,
         footprintMemory: UInt64) {
        self.date = date
        self.duration = duration
        self.activity = activity
        self.callStack = callStack
        self.appCPUUsage = appCPUUsage
        self.footprintMemory = footprintMemory
    }

    var title: String {
        return "卡顿 \(Int(duration * 1000))ms"
    }

    var subtitle: String {
        return "\(date.time)  CPU \(String(format: "%.1f", appCPUUsage))%  MEM \(footprintMemory.formattedAsDataSize())"
    }

    var detailText: String {
        return [
            "时间: \(date.time)",
            "持续: \(Int(duration * 1000))ms",
            "RunLoop: \(activity)",
            "App CPU: \(String(format: "%.1f", appCPUUsage))%",
            "进程内存: \(footprintMemory.formattedAsDataSize())",
            "",
            "调用栈:",
            callStack.joined(separator: "\n")
        ].joined(separator: "\n")
    }
}

final class DYLagMonitor {
    static let shared = DYLagMonitor()

    private static let minimumThreshold: TimeInterval = 0.05
    private let enabledKey = "JYKit.DYLagMonitor.enabled"
    private let thresholdKey = "JYKit.DYLagMonitor.threshold"
    private let defaults = UserDefaults.standard
    private let stateLock = NSLock()
    private let monitorQueue = DispatchQueue(label: "com.jykit.dytool.lag-monitor")

    private var observer: CFRunLoopObserver?
    private var semaphore = DispatchSemaphore(value: 0)
    private var isRunning = false
    private var lastActivity: CFRunLoopActivity = []
    private var latestMainStack: [String] = []
    private var lastRecordDate: Date?

    private(set) var records: [DYLagRecord] = []
    var onRecordsChanged: (() -> Void)?

    var isEnabled: Bool {
        guard defaults.object(forKey: enabledKey) != nil else {
            return false
        }
        return defaults.bool(forKey: enabledKey)
    }

    var threshold: TimeInterval {
        let stored = defaults.double(forKey: thresholdKey)
        return stored > 0 ? stored : 0.5
    }

    func startIfNeeded() {
        if isEnabled {
            start()
        }
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: enabledKey)
        enabled ? start() : stop()
    }

    func setThreshold(_ threshold: TimeInterval) {
        defaults.set(Self.normalizedThreshold(threshold), forKey: thresholdKey)
    }

    func clearRecords() {
        records.removeAll()
        onRecordsChanged?()
    }

    func start() {
        stateLock.lock()
        guard !isRunning else {
            stateLock.unlock()
            return
        }
        isRunning = true
        semaphore = DispatchSemaphore(value: 0)
        latestMainStack = []
        lastRecordDate = nil
        stateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.installObserver()
        }
        monitorQueue.async { [weak self] in
            self?.runMonitorLoop()
        }
    }

    func stop() {
        stateLock.lock()
        guard isRunning else {
            stateLock.unlock()
            return
        }
        isRunning = false
        semaphore.signal()
        stateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.removeObserver()
        }
    }
}

private extension DYLagMonitor {
    static func normalizedThreshold(_ threshold: TimeInterval) -> TimeInterval {
        guard threshold.isFinite, threshold > 0 else {
            return 0.5
        }
        return max(threshold, minimumThreshold)
    }

    func installObserver() {
        guard observer == nil else {
            return
        }

        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.allActivities.rawValue, true, 0) { [weak self] _, activity in
            self?.recordActivity(activity)
        }
        self.observer = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    func removeObserver() {
        guard let observer = observer else {
            return
        }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = nil
    }

    func recordActivity(_ activity: CFRunLoopActivity) {
        stateLock.lock()
        lastActivity = activity
        latestMainStack = Thread.callStackSymbols
        stateLock.unlock()
        semaphore.signal()
    }

    func runMonitorLoop() {
        while true {
            stateLock.lock()
            let running = isRunning
            let currentThreshold = threshold
            stateLock.unlock()

            guard running else {
                return
            }

            let result = semaphore.wait(timeout: .now() + currentThreshold)
            stateLock.lock()
            let activity = lastActivity
            let stack = latestMainStack
            stateLock.unlock()

            if result == .timedOut, isPotentialLagActivity(activity) {
                appendRecord(duration: currentThreshold, activity: activityDescription(activity), callStack: stack)
            }
        }
    }

    func appendRecord(duration: TimeInterval, activity: String, callStack: [String]) {
        let now = Date()
        if let lastRecordDate = lastRecordDate,
           now.timeIntervalSince(lastRecordDate) < max(duration, 1) {
            return
        }
        lastRecordDate = now

        let record = DYLagRecord(
            date: now,
            duration: duration,
            activity: activity,
            callStack: callStack.isEmpty ? ["主线程超时，暂无调用栈样本"] : callStack,
            appCPUUsage: JYDeviceInfo.appCpuUsage(),
            footprintMemory: JYDeviceInfo.footprintMemory()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.records.insert(record, at: 0)
            if self.records.count > 80 {
                self.records.removeLast(self.records.count - 80)
            }
            self.onRecordsChanged?()
        }
    }

    func isPotentialLagActivity(_ activity: CFRunLoopActivity) -> Bool {
        return activity.contains(.beforeSources) || activity.contains(.afterWaiting)
    }

    func activityDescription(_ activity: CFRunLoopActivity) -> String {
        if activity.contains(.entry) {
            return "entry"
        }
        if activity.contains(.beforeTimers) {
            return "beforeTimers"
        }
        if activity.contains(.beforeSources) {
            return "beforeSources"
        }
        if activity.contains(.beforeWaiting) {
            return "beforeWaiting"
        }
        if activity.contains(.afterWaiting) {
            return "afterWaiting"
        }
        if activity.contains(.exit) {
            return "exit"
        }
        return "\(activity.rawValue)"
    }
}

private final class DYLagSwitchCell: UITableViewCell {
    static let identifier = "DYLagSwitchCell"

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

private final class DYLagThresholdCell: UITableViewCell {
    static let identifier = "DYLagThresholdCell"

    let segmentedControl = UISegmentedControl(items: ["300ms", "500ms", "1s"])

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.text = "阈值"
        textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        accessoryView = segmentedControl
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        accessoryView = segmentedControl
    }
}

final class DYLagMonitorVC: DYBaseVC {
    private enum Section: Int, CaseIterable {
        case settings
        case records
    }

    private let recordCellIdentifier = "DYLagRecordCell"
    private let customThresholdCellIdentifier = "DYLagCustomThresholdCell"
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let thresholds: [TimeInterval] = [0.3, 0.5, 1]

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "卡顿监控"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(exportRecords)),
            UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearRecords))
        ]

        tableView.register(DYLagSwitchCell.self, forCellReuseIdentifier: DYLagSwitchCell.identifier)
        tableView.register(DYLagThresholdCell.self, forCellReuseIdentifier: DYLagThresholdCell.identifier)
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

        DYLagMonitor.shared.onRecordsChanged = { [weak self] in
            self?.tableView.reloadSections(IndexSet(integer: Section.records.rawValue), with: .automatic)
        }
    }

    deinit {
        DYLagMonitor.shared.onRecordsChanged = nil
    }

    @objc private func onSwitchChanged(_ sender: UISwitch) {
        DYLagMonitor.shared.setEnabled(sender.isOn)
    }

    @objc private func onThresholdChanged(_ sender: UISegmentedControl) {
        guard sender.selectedSegmentIndex != UISegmentedControl.noSegment else {
            return
        }
        guard thresholds.indices.contains(sender.selectedSegmentIndex) else {
            return
        }
        DYLagMonitor.shared.setThreshold(thresholds[sender.selectedSegmentIndex])
        tableView.reloadSections(IndexSet(integer: Section.settings.rawValue), with: .none)
    }

    @objc private func clearRecords() {
        Tools.showAlert(title: "确认清空卡顿记录？", confirmHandler: {
            DYLagMonitor.shared.clearRecords()
        })
    }

    @objc private func exportRecords() {
        let text = DYLagMonitor.shared.records.map { $0.detailText }.joined(separator: "\n\n---\n\n")
        guard !text.isEmpty else {
            JYToast.show("暂无卡顿记录")
            return
        }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activity.popoverPresentationController?.sourceView = view
        }
        present(activity, animated: true)
    }

    private func selectedThresholdIndex() -> Int {
        let threshold = DYLagMonitor.shared.threshold
        return thresholds.firstIndex { abs($0 - threshold) < 0.001 } ?? UISegmentedControl.noSegment
    }

    private func thresholdText() -> String {
        return "\(Int(round(DYLagMonitor.shared.threshold * 1000)))ms"
    }

    private func showCustomThresholdInput() {
        let alert = UIAlertController(title: "自定义阈值", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "毫秒"
            textField.text = self?.thresholdText().replacingOccurrences(of: "ms", with: "")
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text,
                  let milliseconds = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  milliseconds > 0 else {
                JYToast.show("阈值无效")
                return
            }
            DYLagMonitor.shared.setThreshold(milliseconds / 1000)
            self?.tableView.reloadSections(IndexSet(integer: Section.settings.rawValue), with: .none)
        }))
        present(alert, animated: true)
    }
}

extension DYLagMonitorVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .settings:
            return 3
        case .records:
            return max(DYLagMonitor.shared.records.count, 1)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .settings:
            return nil
        case .records:
            return "记录"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .settings:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: DYLagSwitchCell.identifier, for: indexPath) as! DYLagSwitchCell
                cell.textLabel?.text = "卡顿监控"
                cell.toggle.removeTarget(nil, action: nil, for: .valueChanged)
                cell.toggle.isOn = DYLagMonitor.shared.isEnabled
                cell.toggle.addTarget(self, action: #selector(onSwitchChanged), for: .valueChanged)
                return cell
            }

            if indexPath.row == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: DYLagThresholdCell.identifier, for: indexPath) as! DYLagThresholdCell
                cell.segmentedControl.removeTarget(nil, action: nil, for: .valueChanged)
                cell.segmentedControl.selectedSegmentIndex = selectedThresholdIndex()
                cell.segmentedControl.addTarget(self, action: #selector(onThresholdChanged), for: .valueChanged)
                return cell
            }

            let customCell = tableView.dequeueReusableCell(withIdentifier: customThresholdCellIdentifier) ??
                UITableViewCell(style: .value1, reuseIdentifier: customThresholdCellIdentifier)
            customCell.textLabel?.text = "自定义阈值"
            customCell.detailTextLabel?.text = thresholdText()
            customCell.accessoryType = .disclosureIndicator
            customCell.selectionStyle = .default
            return customCell
        case .records:
            let cell = tableView.dequeueReusableCell(withIdentifier: recordCellIdentifier) ??
                UITableViewCell(style: .subtitle, reuseIdentifier: recordCellIdentifier)
            let records = DYLagMonitor.shared.records
            guard records.indices.contains(indexPath.row) else {
                cell.textLabel?.text = "暂无记录"
                cell.detailTextLabel?.text = DYLagMonitor.shared.isEnabled ? "卡顿发生后会显示在这里" : "打开卡顿监控后开始记录"
                cell.accessoryType = .none
                selectionStyle(for: cell, isSelectable: false)
                return cell
            }

            let record = records[indexPath.row]
            cell.textLabel?.text = record.title
            cell.detailTextLabel?.text = record.subtitle
            cell.detailTextLabel?.textColor = .gray
            cell.accessoryType = .disclosureIndicator
            selectionStyle(for: cell, isSelectable: true)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .settings, indexPath.row == 2 {
            showCustomThresholdInput()
            return
        }
        guard Section(rawValue: indexPath.section) == .records,
              DYLagMonitor.shared.records.indices.contains(indexPath.row) else {
            return
        }
        navigationController?.pushViewController(DYLagRecordDetailVC(record: DYLagMonitor.shared.records[indexPath.row]), animated: true)
    }

    private func selectionStyle(for cell: UITableViewCell, isSelectable: Bool) {
        cell.selectionStyle = isSelectable ? .default : .none
    }
}

final class DYLagRecordDetailVC: DYBaseVC {
    private let textView = UITextView()
    private let record: DYLagRecord

    init(record: DYLagRecord) {
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = record.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "复制", style: .done, target: self, action: #selector(copyDetail))
        textView.isEditable = false
        textView.font = UIFont(name: "Menlo", size: 12) ?? .systemFont(ofSize: 12)
        textView.text = record.detailText
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func copyDetail() {
        UIPasteboard.general.string = record.detailText
        JYToast.show("已复制")
    }
}
