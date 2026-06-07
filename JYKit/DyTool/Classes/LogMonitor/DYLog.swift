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
            guard let self = self else { return }
            self.flushCache()
        }
        timer.resume()
        flushTimer = timer
    }
    
    private func flushCache() {
        queue.async {
            defer { self.lastFlushTime = Date() }
            guard !self.cache.isEmpty else { return }
            let logMessages = self.cache.joined()
            if let data = logMessages.data(using: .utf8) {
                self.fileHandle.write(data)
            }
            self.cache.removeAll()
        }
    }
    
    
    func getStdLog() -> String {
        return (try? String(contentsOfFile: logFilePath)) ?? ""
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
                flushCache()
            }
        }
    }
}
