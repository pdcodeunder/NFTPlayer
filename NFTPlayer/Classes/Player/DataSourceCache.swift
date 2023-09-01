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

fileprivate
struct CacheCodable: Codable {
    let length: UInt64
    let ranges: [CacheRange]
    let mimeType: String?
}

enum DataSourceError: Error {
    case noCache
    case readFileError
    case network
    case requestIsEmpty
}

class DataSourceCache {
    /// 清除缓存
    static func clearCache() {
        
    }
    /// 获取缓存大小
    static func getCacheSize() -> CGFloat {
        return 0
    }
    
    var videoLength: UInt64 = 0
    var mimeType: String?
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
    
    func readData(offset: UInt64, length: UInt64, data: ((Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalReadData(offset: offset, length: length, data: data, complete: complete)
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
        let pathUrl = docFolderURL.appendingPathComponent("player/\(cacheKey)/")
        let fileName = self.url.lastPathComponent
        let fileURL = pathUrl.appendingPathComponent(fileName)
        let path = fileURL.path
        devPrint("------path: \(path)")
        if FileManager.default.fileExists(atPath: path) {
            writeFileHandle = try? FileHandle(forUpdating: fileURL)
            readFileHandle = try? FileHandle(forUpdating: fileURL)
        } else {
            try? FileManager.default.createDirectory(at: pathUrl, withIntermediateDirectories: true)
            if FileManager.default.createFile(atPath: path, contents: nil) {
                writeFileHandle = try? FileHandle(forUpdating: fileURL)
                readFileHandle = try? FileHandle(forUpdating: fileURL)
            }
        }
    }
    
    private func internalReadData(offset: UInt64, length: UInt64, data: ((Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        guard videoLength > 10 else {
            complete?(.noCache)
            return
        }
        print("-------read data offset: \(offset), length: \(length)")
        var hasCache = false
        dataRanges.forEach { item in
            if item.offset <= offset, item.max >= offset + length {
                hasCache = true
            }
        }
        if hasCache {
            stepReadFileData(offset: offset, length: length, dataBlock: data, complete: complete)
        } else {
            complete?(.noCache)
        }
    }
    
    private func stepReadFileData(offset: UInt64, length: UInt64, dataBlock: ((Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        func readData(local: UInt64, count: Int) -> Data? {
            guard let readFileHandle else { return nil }
            do {
                try readFileHandle.seek(toOffset: local)
                if #available(iOS 13.4, *) {
                    let data = try readFileHandle.read(upToCount: count)
                    return data
                } else {
                    let data = readFileHandle.readData(ofLength: count)
                    return data
                }
            } catch _ { }
            return nil
        }
        /// 避免单次读文件过长导致内存过高问题，设置一个读取步长
        let stepSize: UInt64 = 51200
        var currentOffset = offset
        var currentLength = length
        while currentLength > stepSize {
            if let data = readData(local: currentOffset, count: Int(stepSize)) {
                dataBlock?(data)
            } else {
                complete?(.readFileError)
                return
            }
            currentOffset += stepSize
            currentLength -= stepSize
        }
        if let data = readData(local: currentOffset, count: Int(currentLength)) {
            dataBlock?(data)
        } else {
            complete?(.readFileError)
            return
        }
        complete?(nil)
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
        func stepWriteDataToFile(offset: Int, length: Int) -> Bool {
            let beginIndex = data.index(data.startIndex, offsetBy: offset)
            let endIndex = data.index(beginIndex, offsetBy: length)
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
            
            return true
        }
        while moreCount > stepSize {
            if !stepWriteDataToFile(offset: dataOffset, length: moreCount) {
                complete?(nil)
                return
            }
            dataOffset += stepSize
            moreCount -= stepSize
        }
        if !stepWriteDataToFile(offset: dataOffset, length: moreCount) {
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
                    print("------- sava cache range: \(currentRange.offset), offset: \(currentRange.length)")
                    currentRange = item
                } else if item.max > currentRange.max {
                    currentRange.length = item.max - currentRange.offset
                }
            }
            list.append(currentRange)
            print("------- sava cache range: \(currentRange.offset), offset: \(currentRange.length)")
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
        let encodeModel = CacheCodable(length: videoLength, ranges: dataRanges, mimeType: mimeType)
        let data = try? JSONEncoder().encode(encodeModel)
        FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil)
        print("save----: \(fileURL)")
    }
    
    private func unarchiveCacheRanges() {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource cache read documentDirectory error")
        }
        let fileURL = docFolderURL.appendingPathComponent("player/\(cacheKey)/cache_ranges")
        let model = try? JSONDecoder().decode(CacheCodable.self, from: Data(contentsOf: fileURL))
        dataRanges = model?.ranges ?? []
        videoLength = model?.length ?? 0
        mimeType = model?.mimeType
    }
}
