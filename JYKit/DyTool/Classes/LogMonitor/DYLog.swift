//
//  DyLog.swift
//  DyTool
//
//  Created by crazyball on 2022/7/16.
//

import Foundation

@objcMembers
@objc public class DYLog: NSObject {
    public static let sharedInstance = DYLog()

    var logFilePath: String
    var fileHandle: FileHandle

    private let queue: DispatchQueue = DispatchQueue(label: "com.dytools.logQueue", qos: .utility, target: nil)
    private let maxCacheCount = 15 // 最大缓存数量
    private let maxCacheInterval: TimeInterval = 15 // 最长缓存时间，单位为秒
    private var cache: [String] = [] // 缓存日志信息的数组
    private var lastFlushTime: Date = Date() // 上一次写入到文件的时间
    private var flushTimer: DispatchSourceTimer?


    private override init() {
        let logFileDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.appending("/DYLog")
        if !FileManager.default.fileExists(atPath: logFileDir) {
            try? FileManager.default.createDirectory(atPath: logFileDir, withIntermediateDirectories: true, attributes: nil)
        }
        logFilePath = logFileDir.appending("/std.log")
        if FileManager.default.fileExists(atPath: logFilePath) {
            try? FileManager.default.removeItem(atPath: logFilePath)
        }
        FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil)
        fileHandle = FileHandle(forWritingAtPath: logFilePath)!
        fileHandle.seekToEndOfFile()
        super.init()
        startFlushTimer()
    }

    private func startFlushTimer() {
        guard flushTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(3))
        timer.setEventHandler { [weak self] in
            self?.flushLocked()
        }
        timer.resume()
        flushTimer = timer
    }

    /// 调用方必须已经在 `queue` 上。
    private func flushLocked() {
        defer { self.lastFlushTime = Date() }
        guard !self.cache.isEmpty else { return }
        let logMessages = self.cache.joined()
        if let data = logMessages.data(using: .utf8) {
            self.fileHandle.write(data)
        }
        self.cache.removeAll()
    }


    func getStdLog() -> String {
        return (try? String(contentsOfFile: logFilePath)) ?? ""
    }

    /// 增量读取日志：只返回 `offset` 之后的新增内容，避免反复读整个文件。
    /// - Parameter offset: 上次读取到的文件偏移量
    /// - Returns: 新增文本和新的偏移量
    func readNewLog(fromOffset offset: UInt64) -> (text: String, offset: UInt64) {
        return queue.sync {
            flushLocked()

            guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: logFilePath)) else {
                return ("", offset)
            }
            defer { try? handle.close() }

            let fileSize = (try? handle.seekToEnd()) ?? 0
            // 文件被清空或重建，从头开始读
            let start = offset > fileSize ? 0 : offset
            guard start < fileSize else {
                return ("", start)
            }

            try? handle.seek(toOffset: start)
            let data = handle.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8) ?? "", start + UInt64(data.count))
        }
    }

    func clear() {
        queue.sync {
            cache.removeAll()
            fileHandle.truncateFile(atOffset: 0)
            fileHandle.seekToEndOfFile()
            lastFlushTime = Date()
        }
    }


    public func log(_ str: String) {
        queue.sync {
            cache.append(str)
            if cache.count > maxCacheCount || Date().timeIntervalSince(lastFlushTime) > maxCacheInterval {
                flushLocked()
            }
        }
    }
}
