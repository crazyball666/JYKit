//
//  DYLogVC.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

class DYLogVC: DYBaseVC {
    let textView = UITextView()
    let switchView = UISwitch()
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "日志监控"
        view.addSubview(textView)
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        textView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        textView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        switchView.isOn = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: {[weak self] timer in
            self?.loadLog()
        })
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(onTapExport)),
            UIBarButtonItem(customView: switchView)
        ]
        loadLog()
    }
    
    @objc func onTapExport() {
        guard let sdFile = try? SDFileManager.shared.getFile(DYLog.sharedInstance.logFilePath) else { return }
        let filePath = URL(fileURLWithPath: sdFile.filepath)
        let air = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
        self.present(air, animated: true, completion: nil)
    }
    
    
    func loadLog() {
        let log = DYLog.sharedInstance.getStdLog()
        if !log.isEmpty {
            textView.text = log
            let textCount: Int = textView.text.count
            guard textCount >= 1, switchView.isOn else { return }
            textView.scrollRangeToVisible(NSRange(location: textCount - 1, length: 1))
        }
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
}
