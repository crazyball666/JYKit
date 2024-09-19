//
//  FileContentVC.swift
//  DynamicTools
//
//  Created by crazyball on 2023/7/31.
//

import Foundation

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


