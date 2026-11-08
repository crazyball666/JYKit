//
//  DYMonitorSettingsVC.swift
//  JYKit
//

import UIKit

private final class DYMonitorMetricCell: UITableViewCell {
    static let identifier = "DYMonitorMetricCell"

    let toggle = UISwitch()
    let titleLabel = UILabel()
    let detailLabel = UILabel()
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
        selectionStyle = .none
        accessoryView = toggle

        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = DYStyle.text

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = DYStyle.secondaryText
        detailLabel.numberOfLines = 2

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
}

final class DYMonitorSettingsVC: DYBaseVC {
    private enum Section: Int, CaseIterable {
        case monitor
        case metrics
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let metrics = DYMonitorMetric.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "悬浮监控设置"

        tableView.register(DYMonitorMetricCell.self, forCellReuseIdentifier: DYMonitorMetricCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func onMonitorToggleChanged(_ sender: UISwitch) {
        DYMonitorConfiguration.shared.setMonitoringEnabled(sender.isOn)
        DYMonitorView.shared.reloadConfiguration()
        tableView.reloadSections(IndexSet(integer: Section.metrics.rawValue), with: .none)
    }

    @objc private func onToggleChanged(_ sender: UISwitch) {
        guard metrics.indices.contains(sender.tag) else {
            return
        }
        DYMonitorConfiguration.shared.setEnabled(sender.isOn, for: metrics[sender.tag])
        DYMonitorView.shared.reloadConfiguration()
    }
}

extension DYMonitorSettingsVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .monitor:
            return 1
        case .metrics:
            return metrics.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .monitor:
            return "总开关"
        case .metrics:
            return "展示指标"
        case .none:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard Section(rawValue: section) == .metrics else {
            return nil
        }
        return DYMonitorConfiguration.shared.isMonitoringEnabled ? "关闭总开关后悬浮窗会隐藏" : "开启总开关后，选中的指标会显示在悬浮窗中"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DYMonitorMetricCell.identifier, for: indexPath) as! DYMonitorMetricCell
        cell.toggle.removeTarget(nil, action: nil, for: .valueChanged)

        guard let section = Section(rawValue: indexPath.section) else {
            return cell
        }

        switch section {
        case .monitor:
            cell.titleLabel.text = "悬浮监控"
            cell.detailLabel.text = "关闭后悬浮窗整体隐藏"

            cell.toggle.tag = -1
            cell.toggle.isOn = DYMonitorConfiguration.shared.isMonitoringEnabled
            cell.toggle.addTarget(self, action: #selector(onMonitorToggleChanged), for: .valueChanged)
            cell.isUserInteractionEnabled = true
        case .metrics:
            let metric = metrics[indexPath.row]
            cell.titleLabel.text = metric.title
            cell.detailLabel.text = metric.detail
            cell.toggle.tag = indexPath.row
            cell.toggle.isOn = DYMonitorConfiguration.shared.isEnabled(metric)
            cell.toggle.isEnabled = DYMonitorConfiguration.shared.isMonitoringEnabled
            cell.toggle.addTarget(self, action: #selector(onToggleChanged), for: .valueChanged)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? DYMonitorMetricCell,
              cell.toggle.isEnabled else {
            return
        }
        cell.setOn(!cell.toggle.isOn, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .monitor:
            onMonitorToggleChanged(cell.toggle)
        case .metrics:
            onToggleChanged(cell.toggle)
        }
    }
}

private extension DYMonitorMetricCell {
    func setOn(_ isOn: Bool, animated: Bool) {
        toggle.setOn(isOn, animated: animated)
    }
}

extension DYMonitorMetric {
    var detail: String {
        switch self {
        case .fps:
            return "页面刷新率，越低越可能掉帧"
        case .memory:
            return "当前进程已占用的物理内存"
        case .availableMemory:
            return "设备剩余可用内存"
        case .cpu:
            return "App 进程 CPU 占用"
        case .systemCPU:
            return "整机 CPU 占用"
        case .sent:
            return "网络上行速率"
        case .received:
            return "网络下行速率"
        case .battery:
            return "设备剩余电量"
        case .thermal:
            return "设备温度状态"
        }
    }
}
