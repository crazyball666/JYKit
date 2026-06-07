//
//  FileContentVC.swift
//  DynamicTools
//
//  Created by crazyball on 2023/7/31.
//

import Foundation
import SQLite3
import UIKit

protocol IFileContentHandler {
    var path: String { get }
    func getContent() throws -> String
    func saveContent(content: String) throws
}

/// Plist 处理器
class PlistContentHandler: IFileContentHandler {
    var path: String
    var format: PropertyListSerialization.PropertyListFormat = .binary
    
    func getContent() throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var format: PropertyListSerialization.PropertyListFormat = .binary
        let info = try PropertyListSerialization.propertyList(from: data, format: &format)
        self.format = format
        let xml = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        return String(data: xml, encoding: .utf8) ?? ""
    }
    
    func saveContent(content: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "string convert to data error"])
        }
        let info = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plistData = try PropertyListSerialization.data(fromPropertyList: info, format: self.format, options: 0)
        try plistData.write(to: URL(fileURLWithPath: self.path))
    }
    
    init(path: String) {
        self.path = path
    }
}

/// 文本处理器
struct TextContentHandler: IFileContentHandler {
    var path: String
    
    func getContent() throws -> String {
        try String(contentsOfFile: path)
    }
    
    func saveContent(content: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// JSON 处理器
struct JSONContentHandler: IFileContentHandler {
    var path: String

    func getContent() throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(data: prettyData, encoding: .utf8) ?? ""
    }

    func saveContent(content: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "string convert to data error"])
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try prettyData.write(to: URL(fileURLWithPath: path))
    }
}


class FileContentVC: UIViewController {
    let path: String
    var contentView: UITextView?
    
    init(path: String) {
        self.path = path
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    lazy var fileContentHandler: IFileContentHandler = {
        let pathExtension = (path as NSString).pathExtension
        switch pathExtension {
        case "plist":
            return PlistContentHandler(path: path)
        case "json":
            return JSONContentHandler(path: path)
        default:
            return TextContentHandler(path: path)
        }
    }()
    
    override func viewDidLoad() {
        view.backgroundColor = .white
        navigationItem.title = (self.path as NSString).lastPathComponent
        let pathExtension = (self.path as NSString).pathExtension
        
        if ["png", "jpg", "jpeg"].contains(pathExtension) {
            let imageView = UIImageView()
            view.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
            imageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8).isActive = true
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.8).isActive = true
            imageView.image = UIImage(contentsOfFile: path)
        } else {
            let contentView = UITextView()
            self.contentView = contentView
            view.addSubview(contentView)
            contentView.backgroundColor = .black
            contentView.textColor = .white
            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            
            let content: String
            do {
                content = try fileContentHandler.getContent()
                navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(onTapSave))
                contentView.isEditable = true
            } catch {
                content = "读取失败：\(error.localizedDescription)"
                contentView.isEditable = false
            }
            contentView.text = content
        }
    }
    
    
    @objc func onTapSave() {
        guard let contentView = contentView, contentView.isEditable else {
            return
        }
        Tools.showAlert(title: "是否修改内容？", confirmHandler: {
            do {
                try self.fileContentHandler.saveContent(content: contentView.text)
                JYToast.show("保存成功")
                contentView.text = try self.fileContentHandler.getContent()
            } catch {
                JYToast.show("保存失败：\(error.localizedDescription)")
            }
        })
    }
}

class SQLiteBrowserVC: UIViewController {
    private let path: String
    private let tableView = UITableView()
    private var tables: [String] = []

    init(path: String) {
        self.path = path
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationItem.title = (path as NSString).lastPathComponent
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SQLiteTableCell")
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
        loadTables()
    }

    private func loadTables() {
        tables = SQLiteReader(path: path).tables()
        tableView.reloadData()
    }
}

extension SQLiteBrowserVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tables.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SQLiteTableCell", for: indexPath)
        cell.textLabel?.text = tables[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(SQLiteTableDataVC(path: path, tableName: tables[indexPath.row]), animated: true)
    }
}

private class SQLiteTableDataVC: UIViewController {
    private let path: String
    private let tableName: String
    private let textView = UITextView()

    init(path: String, tableName: String) {
        self.path = path
        self.tableName = tableName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = tableName
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.font = UIFont(name: "Menlo", size: 12) ?? .systemFont(ofSize: 12)
        textView.isEditable = false
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        textView.text = SQLiteReader(path: path).preview(tableName: tableName, limit: 100)
    }
}

private final class SQLiteReader {
    let path: String

    init(path: String) {
        self.path = path
    }

    func tables() -> [String] {
        query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") { statement in
            guard let text = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: text)
        }
    }

    func preview(tableName: String, limit: Int) -> String {
        let escapedName = tableName.replacingOccurrences(of: "\"", with: "\"\"")
        let rows = query("SELECT * FROM \"\(escapedName)\" LIMIT \(limit)") { statement -> String? in
            let columnCount = sqlite3_column_count(statement)
            var values: [String] = []
            for index in 0..<columnCount {
                let name = sqlite3_column_name(statement, index).map { String(cString: $0) } ?? "\(index)"
                let value: String
                switch sqlite3_column_type(statement, index) {
                case SQLITE_NULL:
                    value = "NULL"
                case SQLITE_INTEGER:
                    value = "\(sqlite3_column_int64(statement, index))"
                case SQLITE_FLOAT:
                    value = "\(sqlite3_column_double(statement, index))"
                case SQLITE_BLOB:
                    value = "BLOB(\(sqlite3_column_bytes(statement, index)) bytes)"
                default:
                    value = sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
                }
                values.append("\(name)=\(value)")
            }
            return values.joined(separator: " | ")
        }
        return rows.isEmpty ? "暂无数据" : rows.enumerated().map { "#\($0.offset + 1) \($0.element)" }.joined(separator: "\n\n")
    }

    private func query<T>(_ sql: String, map: (OpaquePointer?) -> T?) -> [T] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = db else {
            return []
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var result: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = map(statement) {
                result.append(value)
            }
        }
        return result
    }
}
