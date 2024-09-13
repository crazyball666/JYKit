//
//  DemoVC.swift
//  JYKit_Example
//
//  Created by crazyball on 2023/7/31.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import UIKit

struct CellInfo {
    var title: String
    var selector: Selector?
    var info: Any?
}

class DemoVC: UIViewController {
    let outputView: UITextView = {
       let view = UITextView()
        view.backgroundColor = .systemTeal
        view.textColor = .white
        view.tintColor = .systemBlue
        view.isEditable = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let tableView: UITableView = {
        let view = UITableView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var examples: [CellInfo] { [] }
    
    func setupUI() {
        view.addSubview(outputView)
        view.addSubview(tableView)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DemoCell")
        tableView.dataSource = self
        tableView.delegate = self
        
        outputView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        outputView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        outputView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        outputView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35).isActive = true
        
        tableView.topAnchor.constraint(equalTo: outputView.bottomAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    func addLog(_ text: String) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: now)
        DispatchQueue.main.async { [self] in
            let oldText = outputView.text
            outputView.text = String(format: "%@[%@]：%@", oldText!.count > 0 ? "\(oldText!)\n" : "", dateString, text)
            outputView.scrollToBottom()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        setupUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}


extension DemoVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return examples.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DemoCell", for: indexPath)
        let row = indexPath.row
        let model = examples[row]
        cell.textLabel?.text = model.title
        return cell
    }
}

extension DemoVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        
        let model = examples[row]
        if responds(to: model.selector) {
            if model.info == nil {
                perform(model.selector)
            } else {
                perform(model.selector, with: model.info)
            }
        }
    }
}

extension UITextView {
    func scrollToBottom() {
        let textCount: Int = text.count
        guard textCount >= 1 else { return }
        scrollRangeToVisible(NSRange(location: textCount - 1, length: 1))
    }
}
