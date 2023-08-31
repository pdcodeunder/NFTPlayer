//
//  DataSourceCache.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/29.
//

import Foundation

struct CacheRange: Codable {
    var offset: UInt64 = 0
    var length: UInt64 = 0
    
    var max: UInt64 {
        return offset + length
    }
    
    func contain(_ range: CacheRange) -> Bool {
        return offset <= range.offset && max >= range.max
    }
}

class DataSourceCache {
    /// 清除缓存
    static func clearCache() {
        
    }
    /// 获取缓存大小
    static func getCacheSize() -> CGFloat {
        return 0
    }
    
    let url: URL
    let cacheKey: String
    private var writeFileHandle: FileHandle?
    private var readFileHandle: FileHandle?
    /// 存储当前写入文件的range
    private var dataRanges: [CacheRange] = []
    private let handleQueue = DispatchQueue(label: "com.player.cache.key")
    
    deinit {
        try? writeFileHandle?.close()
        try? readFileHandle?.close()
    }
    
    init(url: URL) {
        self.url = url
        cacheKey = PlayerUtil.md5(url.absoluteString)
        createFileHandler()
        unarchiveCacheRanges()
    }
    
    func readData(offset: UInt64, length: UInt64, complete: (([(UInt64, Data)]) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalReadData(offset: offset, length: length, complete: complete)
        }
    }
    
    func writeData(_ data: Data, offset: UInt64, complete: ((Data?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalWriteData(data, offset: offset, complete: complete)
        }
    }
}

extension DataSourceCache {
    private func createFileHandler() {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource cache read documentDirectory error")
        }
        let fileName = self.url.lastPathComponent
        let fileURL = docFolderURL.appendingPathComponent("player/\(cacheKey)/\(fileName)")
        let path = fileURL.path
        if FileManager.default.fileExists(atPath: path) {
            writeFileHandle = try? FileHandle(forUpdating: fileURL)
            readFileHandle = try? FileHandle(forUpdating: fileURL)
        } else if FileManager.default.createFile(atPath: path, contents: nil) {
            writeFileHandle = try? FileHandle(forUpdating: fileURL)
            readFileHandle = try? FileHandle(forUpdating: fileURL)
        }
    }
    
    private func internalReadData(offset: UInt64, length: UInt64, complete: (([(UInt64, Data)]) -> Void)?) {
        
        func readData(local: UInt64, count: Int) -> (UInt64, Data)? {
            guard let readFileHandle else { return nil }
            do {
                try readFileHandle.seek(toOffset: local)
                if #available(iOS 13.4, *) {
                    if let data = try readFileHandle.read(upToCount: count) {
                        return (local, data)
                    }
                } else {
                    let data = readFileHandle.readData(ofLength: count)
                    return (local, data)
                }
            } catch _ { }
            return nil
        }
        
        var list: [(UInt64, Data)] = []
        let readRange = NSRange(location: Int(offset), length: Int(length))
        dataRanges.forEach { item in
            let range = NSRange(location: Int(item.offset), length: Int(item.length))
            /// 判断是否有交集
            if let intersectionRange = readRange.intersection(range),
               intersectionRange.length > 0,
               let readData = readData(local: UInt64(intersectionRange.location), count: intersectionRange.length)
            {
                list.append(readData)
            }
        }
        /// 校验缓存是否正常
        var verify = true
        var currentOffset = offset
        list.forEach { item in
            if item.0 < currentOffset {
                verify = false
            }
            currentOffset = item.0 + UInt64(item.1.count)
        }
        if verify {
            complete?(list)
        } else {
            complete?([])
        }
    }
    
    private func internalWriteData(_ data: Data, offset: UInt64, complete: ((Data?) -> Void)?) {
        guard let writeFileHandle else {
            complete?(nil)
            return
        }
        let fileEndOffset = writeFileHandle.seekToEndOfFile()
        /// 需要写入的位置超过当前句柄内容最大长度，需要先用空白内容填充
        /// 避免单次写入过长失败问题，设置一个写入步长
        let stepSize = 51200
        if offset > fileEndOffset {
            var length = offset - fileEndOffset
            while length > UInt64(stepSize) {
                let emptyData = Data(count: stepSize)
                if #available(iOS 13.4, *) {
                    do {
                        try writeFileHandle.write(contentsOf: emptyData)
                    } catch _ {
                        complete?(nil)
                        return
                    }
                } else {
                    writeFileHandle.write(emptyData)
                }
                length -= UInt64(stepSize)
            }
            let emptyData = Data(count: Int(length))
            if #available(iOS 13.4, *) {
                do {
                    try writeFileHandle.write(contentsOf: emptyData)
                } catch _ {
                    complete?(nil)
                    return
                }
            } else {
                writeFileHandle.write(emptyData)
            }
        } else if offset < fileEndOffset {
            do {
                try writeFileHandle.seek(toOffset: offset)
            } catch _ {
                return
            }
        }
        var moreCount = data.count
        var dataOffset = 0
        func stepWriteDataToFile() -> Bool {
            let beginIndex = data.index(0, offsetBy: dataOffset)
            let endIndex = data.index(dataOffset, offsetBy: stepSize)
            let stepData = data[beginIndex..<endIndex]
            if #available(iOS 13.4, *) {
                do {
                    try writeFileHandle.write(contentsOf: stepData)
                } catch _ {
                    return false
                }
            } else {
                writeFileHandle.write(stepData)
            }
            dataOffset += stepSize
            moreCount -= stepSize
            return true
        }
        while moreCount > stepSize {
            if !stepWriteDataToFile() {
                complete?(nil)
                return
            }
        }
        if !stepWriteDataToFile() {
            complete?(nil)
            return
        }
        dataRanges.append(CacheRange(offset: offset, length: UInt64(data.count)))
        clearUpCacheRangesAndSave()
    }
    
    private func clearUpCacheRangesAndSave() {
        let origin = dataRanges.sorted { one, two in
            if one.offset == two.offset {
                return one.length > two.length
            }
            return one.offset < two.offset
        }
        var list: [CacheRange] = []
        if var currentRange = origin.first {
            origin.forEach { item in
                if item.offset > currentRange.max {
                    list.append(currentRange)
                    currentRange = item
                } else if item.max > currentRange.max {
                    currentRange.length = item.max - currentRange.offset
                }
            }
            list.append(currentRange)
        }
        dataRanges = list
        archiveCacheRanges()
    }
    
    
    /// 保存当前文件真正内容的状态
    private func archiveCacheRanges() {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource cache read documentDirectory error")
        }
        let fileURL = docFolderURL.appendingPathComponent("player/\(cacheKey)/cache_ranges")
        let data = try? JSONEncoder().encode(dataRanges)
        FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil)
    }
    
    private func unarchiveCacheRanges() {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource cache read documentDirectory error")
        }
        let fileURL = docFolderURL.appendingPathComponent("player/\(cacheKey)/cache_ranges")
        let list = try? JSONDecoder().decode([CacheRange].self, from: Data(contentsOf: fileURL))
        dataRanges = list ?? []
    }
}
