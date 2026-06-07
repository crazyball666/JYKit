//
//  DYFloatingView.swift
//  JYKit
//
//  Created by crazyball on 2025/3/2.
//

import UIKit

enum DYMonitorMetric: String, CaseIterable {
    case fps
    case memory
    case availableMemory
    case cpu
    case systemCPU
    case sent
    case received
    case battery
    case thermal

    var title: String {
        switch self {
        case .fps:
            return "FPS"
        case .memory:
            return "进程内存"
        case .availableMemory:
            return "可用内存"
        case .cpu:
            return "App CPU"
        case .systemCPU:
            return "系统 CPU"
        case .sent:
            return "发送速率"
        case .received:
            return "接收速率"
        case .battery:
            return "电量"
        case .thermal:
            return "温度状态"
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .fps, .memory, .cpu, .sent, .received:
            return true
        case .availableMemory, .systemCPU, .battery, .thermal:
            return false
        }
    }

    fileprivate var defaultsKey: String {
        return "JYKit.DYMonitorMetric.\(rawValue).enabled"
    }
}

final class DYMonitorConfiguration {
    static let shared = DYMonitorConfiguration()

    private let defaults = UserDefaults.standard
    private let monitorEnabledKey = "JYKit.DYMonitor.enabled"

    private init() {}

    var isMonitoringEnabled: Bool {
        guard defaults.object(forKey: monitorEnabledKey) != nil else {
            return true
        }
        return defaults.bool(forKey: monitorEnabledKey)
    }

    var enabledMetrics: [DYMonitorMetric] {
        return DYMonitorMetric.allCases.filter { isEnabled($0) }
    }

    var isAnyMetricEnabled: Bool {
        return !enabledMetrics.isEmpty
    }

    var shouldDisplayMonitor: Bool {
        return isMonitoringEnabled && isAnyMetricEnabled
    }

    func setMonitoringEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: monitorEnabledKey)
    }

    func isEnabled(_ metric: DYMonitorMetric) -> Bool {
        guard defaults.object(forKey: metric.defaultsKey) != nil else {
            return metric.defaultEnabled
        }
        return defaults.bool(forKey: metric.defaultsKey)
    }

    func setEnabled(_ isEnabled: Bool, for metric: DYMonitorMetric) {
        defaults.set(isEnabled, forKey: metric.defaultsKey)
    }
}

class DYMonitorView: DYFloatingView {
    static let shared = DYMonitorView()
    
    private var refreshInterval: TimeInterval = 1
    private var timer: Timer?
    private let sampler = DYPerformanceSampler()
    private let contentInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
    
    override var safeFloatingAreaInsets: UIEdgeInsets {
        return .zero
    }
    
    lazy var textView: UILabel = {
        let textView = UILabel()
        if #available(iOS 13.0, *) {
            textView.font = UIFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        } else {
            textView.font = UIFont(name: "Menlo-Regular", size: 11) ??
                                    UIFont(name: "Courier New", size: 11) ??
                                    UIFont.systemFont(ofSize: 11)
        }
        textView.textColor = .white
        textView.numberOfLines = 0
        return textView
    }()
    
    init() {
        super.init(frame: .init(origin: .init(x: 0, y: 60), size: .init(width: 150, height: 84)))
        self.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        layer.cornerRadius = 8
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        layer.borderWidth = 0.5
        clipsToBounds = true
        self.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.topAnchor.constraint(equalTo: self.topAnchor, constant: contentInsets.top).isActive = true
        textView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: contentInsets.left).isActive = true
        textView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -contentInsets.right).isActive = true
        textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -contentInsets.bottom).isActive = true
        edgePolicy = .allEdge
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func install() {
        guard DYMonitorConfiguration.shared.shouldDisplayMonitor else {
            uninstall()
            return
        }
        super.install()
        startTimer()
    }

    override func uninstall() {
        stopTimer()
        super.uninstall()
    }

    func reloadConfiguration() {
        if DYMonitorConfiguration.shared.shouldDisplayMonitor {
            install()
            updateMetrics()
        } else {
            uninstall()
        }
    }
}

private extension DYMonitorView {
    func startTimer() {
        timer?.invalidate()
        sampler.start(options: DYPerformanceSampleOptions(metrics: DYMonitorConfiguration.shared.enabledMetrics))
        updateMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: self.refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }
            self.updateMetrics()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        sampler.stop()
    }

    func updateMetrics() {
        let metrics = DYMonitorConfiguration.shared.enabledMetrics
        guard !metrics.isEmpty else {
            uninstall()
            return
        }

        let snapshot = sampler.sample()
        let lines = metrics.map { lineText(for: $0, snapshot: snapshot) }

        updateSize(lineCount: lines.count)
        textView.text = lines.joined(separator: "\n")
    }

    func updateSize(lineCount: Int) {
        let oldCenter = center
        let textHeight = CGFloat(lineCount * 16)
        frame.size = CGSize(width: 150, height: max(30, textHeight + contentInsets.top + contentInsets.bottom))
        center = oldCenter
    }

    func lineText(for metric: DYMonitorMetric, snapshot: DYPerformanceSnapshot) -> String {
        switch metric {
        case .fps:
            return "FPS  \(snapshot.fps.map(String.init) ?? "--")"
        case .memory:
            return "MEM  \(dataSizeText(snapshot.footprintMemory))"
        case .availableMemory:
            return "AVL  \(dataSizeText(snapshot.availableMemory))"
        case .cpu:
            return "CPU  \(percentText(snapshot.cpuUsage))"
        case .systemCPU:
            return "SYS  \(percentText(snapshot.systemCpuUsage))"
        case .sent:
            return "UP   \(dataSizeText(snapshot.sentBytesPerSecond))/s"
        case .received:
            return "DN   \(dataSizeText(snapshot.receivedBytesPerSecond))/s"
        case .battery:
            return "BAT  \(batteryText(snapshot.batteryLevel))"
        case .thermal:
            return "THM  \(thermalText(snapshot.thermalState))"
        }
    }

    func dataSizeText(_ bytes: UInt64?) -> String {
        guard let bytes = bytes else {
            return "--"
        }
        return bytes.formattedAsDataSize()
    }

    func percentText(_ value: Float?) -> String {
        guard let value = value else {
            return "--"
        }
        return "\(String(format: "%.1f", value))%"
    }

    func batteryText(_ level: Float?) -> String {
        guard let level = level else {
            return "--"
        }
        return "\(Int(round(level * 100)))%"
    }

    func thermalText(_ state: ProcessInfo.ThermalState?) -> String {
        guard let state = state else {
            return "--"
        }
        switch state {
        case .nominal:
            return "Normal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
}
