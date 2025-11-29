//
//  NetInfo.swift
//  SwiftDebug
//
//  Created by linzixin on 2021/12/8.
//

import Foundation
import CoreTelephony

class NetFlowData {
    var totalReceived: UInt64 = 0
    var totalSend: UInt64 = 0
}

class NetInfo {
    /// 获取网络流量信息，单位Byte
    /// totalReceived: 收到的流量
    /// totalSend: 发送的流量
    static func requestNetFlow() -> NetFlowData {
        let data = NetFlowData()
        var ifaddress: UnsafeMutablePointer<ifaddrs>? = nil
        let ret = getifaddrs(&ifaddress)
        defer { freeifaddrs(ifaddress) } // 自动释放
        guard ret == 0, let head = ifaddress?.pointee else {
            return data
        }

        var current: ifaddrs? = head
        while let ifa = current {
//            let name = String(cString: ifa.ifa_name)
            let flags = Int32(ifa.ifa_flags)
            // 只统计 UP 且 RUNNING 的接口（排除 lo 等）
            if flags & IFF_UP != 0 && flags & IFF_RUNNING != 0 {
                if let dataPtr = ifa.ifa_data {
                    let ifData = dataPtr.bindMemory(to: if_data.self, capacity: 1).pointee
                    data.totalReceived += UInt64(ifData.ifi_ibytes)
                    data.totalSend += UInt64(ifData.ifi_obytes)
                }
            }
            if (ifa.ifa_next == nil) {
                break
            }
            current = ifa.ifa_next.pointee
        }
        return data
    }
}
