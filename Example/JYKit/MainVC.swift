//
//  ViewController.swift
//  JYKit
//
//  Created by crazyball on 07/26/2023.
//  Copyright (c) 2023 crazyball. All rights reserved.
//

import UIKit
import JYKit

class MainVC: DemoVC {
    override var examples: [CellInfo] {
        return [
            CellInfo(title: "Toast", selector: #selector(toast))
        ]
    }
}


extension MainVC {
    @objc func toast() {
        JYToast.show("啊手动滑稽阿斯卡带回家卡莎登记卡受打击看哈手机卡核打击啊受打击啊三打哈")
    }
}
