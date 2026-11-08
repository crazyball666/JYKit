//
//  BaseVC.swift
//  DynamicTools
//
//  Created by crazyball on 2023/3/28.
//

import Foundation
import UIKit


class DYBaseVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DYStyle.background
        // 关闭按钮只在工具首页提供，二级页面统一使用系统返回按钮，避免右上角按钮行为不一致。
        if #available(iOS 13.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    @objc func close() {
        DYMainVC.shared.dismiss()
    }
}
