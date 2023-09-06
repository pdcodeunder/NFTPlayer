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
    case requestError
    case cancel
}

class DataSourceCache {
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
    
    func updateVideoLength(_ length: UInt64, mimeType: String?) {
        handleQueue.async { [weak self] in
            self?.internalUpdateVideoLength(length, mimeType: mimeType)
        }
    }
    
    func findData(offset: UInt64, length: UInt64, onQueue: DispatchQueue?, complete: ((UInt64, UInt64) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalFindData(offset: offset, length: length, onQueue: onQueue, complete: complete)
        }
    }
    
    func readData(offset: UInt64, length: UInt64, onQueue: DispatchQueue?, data: ((Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalReadData(offset: offset, length: length, onQueue: onQueue, data: data, complete: complete)
        }
    }
    
    func writeData(_ data: Data, offset: UInt64, complete: ((Data?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalWriteData(data, offset: offset, complete: complete)
        }
    }
}

extension DataSourceCache {
    /// 清除七天缓存
    static func clearOlderThanLastWeekCache() {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource clearLastWeekCache error")
        }
        let fileURL = docFolderURL.appendingPathComponent("player")
        deleteFilesOlderThanSevenDays(inDirectory: fileURL.path)
    }
    /// 清除缓存
    static func clearCache() {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource clearLastWeekCache error")
        }
        let fileURL = docFolderURL.appendingPathComponent("player")
        cleanUnusedFiles(inDirectory: fileURL.path)
    }
    /// 获取缓存大小
    static func getCacheSize() -> UInt64 {
        guard let docFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("player datasource clearLastWeekCache error")
        }
        let fileURL = docFolderURL.appendingPathComponent("player")
        return PlayerUtil.diskSpaceSize(for: fileURL.path)
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
    
    func internalUpdateVideoLength(_ length: UInt64, mimeType: String?) {
        self.videoLength = length
        self.mimeType = mimeType
        archiveCacheRanges()
    }
    
    func internalFindData(offset: UInt64, length: UInt64, onQueue: DispatchQueue?, complete: ((UInt64, UInt64) -> Void)?) {
        guard videoLength > 10 else {
            if let onQueue {
                onQueue.async {
                    complete?(0, 0)
                }
            } else {
                complete?(0, 0)
            }
            return
        }
        var cacheLength: UInt64 = 0
        var cacheOffset: UInt64 = 0
        let list = dataRanges
        list.forEach { item in
            if cacheLength == 0 {
                if item.offset <= offset {
                    if item.max > offset {
                        cacheLength = min(item.max - offset, length)
                        cacheOffset = offset
                    }
                } else if item.offset < offset + length {
                    cacheOffset = item.offset
                    cacheLength = min(offset + length - item.offset, item.length)
                }
            }
        }
        if let onQueue {
            onQueue.async {
                complete?(cacheOffset, cacheLength)
            }
        } else {
            complete?(cacheOffset, cacheLength)
        }
    }
    
    private func internalReadData(offset: UInt64, length: UInt64, onQueue: DispatchQueue?, data: ((Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        guard videoLength > 10 else {
            if let onQueue {
                onQueue.async {
                    complete?(.noCache)
                }
            } else {
                complete?(.noCache)
            }
            return
        }
        var hasCache = false
        let list = dataRanges
        list.forEach { item in
            if item.offset <= offset, item.max >= offset + length {
                hasCache = true
            }
        }
        if hasCache {
            stepReadFileData(offset: offset, length: length, onQueue: onQueue, dataBlock: data, complete: complete)
        } else {
            if let onQueue {
                onQueue.async {
                    complete?(.noCache)
                }
            } else {
                complete?(.noCache)
            }
        }
    }
    
    private func stepReadFileData(offset: UInt64, length: UInt64, onQueue: DispatchQueue?, dataBlock: ((Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
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
                if let onQueue {
                    onQueue.async {
                        dataBlock?(data)
                    }
                } else {
                    dataBlock?(data)
                }
            } else {
                if let onQueue {
                    onQueue.async {
                        complete?(.readFileError)
                    }
                } else {
                    complete?(.readFileError)
                }
                return
            }
            currentOffset += stepSize
            currentLength -= stepSize
        }
        if let data = readData(local: currentOffset, count: Int(currentLength)) {
            if let onQueue {
                onQueue.async {
                    dataBlock?(data)
                }
            } else {
                dataBlock?(data)
            }
        } else {
            if let onQueue {
                onQueue.async {
                    complete?(.readFileError)
                }
            } else {
                complete?(.readFileError)
            }
            return
        }
        if let onQueue {
            onQueue.async {
                complete?(nil)
            }
        } else {
            complete?(nil)
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
        var list = dataRanges
        list.append(CacheRange(offset: offset, length: UInt64(data.count)))
        dataRanges = list
        clearUpCacheRangesAndSave()
    }
    
    private func clearUpCacheRangesAndSave() {
        let dataList = dataRanges
        let origin = dataList.sorted { one, two in
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
        let list = dataRanges
        let encodeModel = CacheCodable(length: videoLength, ranges: list, mimeType: mimeType)
        let data = try? JSONEncoder().encode(encodeModel)
        FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: nil)
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

    private static func deleteFilesOlderThanSevenDays(inDirectory directoryPath: String) {
        let fileManager = FileManager.default
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        do {
            let folderContents = try fileManager.contentsOfDirectory(atPath: directoryPath)
            folderContents.forEach({ fileName in
                let filePath = (directoryPath as NSString).appendingPathComponent("\(fileName)/cache_ranges")
                if let fileAttributes = try? fileManager.attributesOfItem(atPath: filePath),
                   let creationDate = fileAttributes[.modificationDate] as? Date {
                    if creationDate < sevenDaysAgo {
                        let cachePath = (directoryPath as NSString).appendingPathComponent(fileName)
                        try? fileManager.removeItem(atPath: cachePath)
                    }
                }
            })
        } catch {
            print("文件读取 Error: \(error)")
        }
    }

    private static func cleanUnusedFiles(inDirectory directoryPath: String) {
        let fileManager = FileManager.default
        
        do {
            let folderContents = try fileManager.contentsOfDirectory(atPath: directoryPath)
            
            for fileName in folderContents {
                let filePath = (directoryPath as NSString).appendingPathComponent("\(fileName)/cache_ranges")
                // 使用 fileHandleForReading 来尝试打开文件，如果失败表示文件没有被打开
                if let fileHandle = FileHandle(forReadingAtPath: filePath) {
                    fileHandle.closeFile()
                } else {
                    let cachePath = (directoryPath as NSString).appendingPathComponent(fileName)
                    // 如果文件没有被打开，就删除它
                    try? fileManager.removeItem(atPath: cachePath)
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }

}
