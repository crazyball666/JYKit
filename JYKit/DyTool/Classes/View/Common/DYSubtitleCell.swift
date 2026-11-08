//
//  DYSubtitleCell.swift
//  JYKit
//

import UIKit

/// 通用「标题 + 两行副标题」列表 Cell，供 Keychain 等页面复用。
final class DYSubtitleCell: UITableViewCell {
    static let identifier = "DYSubtitleCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupStyle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStyle()
    }

    private func setupStyle() {
        textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        textLabel?.textColor = DYStyle.text
        detailTextLabel?.font = .systemFont(ofSize: 12)
        detailTextLabel?.textColor = DYStyle.secondaryText
        detailTextLabel?.numberOfLines = 2
    }
}
