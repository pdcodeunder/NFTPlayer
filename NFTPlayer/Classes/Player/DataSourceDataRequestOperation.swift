//
//  DataSourceDataRequestOperation.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/9/1.
//

import Foundation

// MARK: - 视频播放一个DataRequest对应一个DataSourceDataRequestOperation，用于管理与当前DataRequest相关的请求的
class DataSourceDataRequestOperation: DataSourceRequestOperationProtocol {
    let session: URLSession?
    let cache: DataSourceCache
    let url: URL
    let requestIdentifer: AnyObject
    let offset: UInt64
    let length: UInt64
    let dataBlock: ((Data) -> Void)?
    let complete: ((Error?) -> Void)?
    let operationQueue: DispatchQueue
    var currentTask: DataSourceRequestTask?
    var currentOffset: UInt64 = 0

    init(operationQueue: DispatchQueue, session: URLSession?, cache: DataSourceCache, url: URL, requestIdentifer: AnyObject, offset: UInt64, length: UInt64, dataBlock: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        self.operationQueue = operationQueue
        self.session = session
        self.cache = cache
        self.url = url
        self.requestIdentifer = requestIdentifer
        self.offset = offset
        self.length = length
        self.dataBlock = dataBlock
        self.complete = complete
        currentOffset = offset
    }
    
    func resume() {
        devPrint("网络层：DataRequest开始获取视频数据")
        checkDataSourcePosition()
    }
    
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if self.currentTask?.task?.taskIdentifier == dataTask.taskIdentifier {
            self.currentTask?.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if self.currentTask?.task?.taskIdentifier == dataTask.taskIdentifier {
            self.currentTask?.urlSession(session, dataTask: dataTask, didReceive: data)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if self.currentTask?.task?.taskIdentifier == task.taskIdentifier {
            self.currentTask?.urlSession(session, task: task, didCompleteWithError: error)
        }
    }
}

extension DataSourceDataRequestOperation {
    private func checkDataSourcePosition() {
        devPrint("网络层：开始检查是否需要从网络获取视频")
        guard currentOffset < offset + length else {
            complete?(nil)
            return
        }
        
        cache.findData(offset: currentOffset, length: offset + length - currentOffset, onQueue: operationQueue) { [weak self] (cacheOffset, cacheLength) in
            self?.findDataFromCacheResponse(cacheOffset: cacheOffset, cacheLength: cacheLength)
        }
    }
    
    private func findDataFromCacheResponse(cacheOffset: UInt64, cacheLength: UInt64) {
        devPrint("网络层：查询到到缓存数据 cacheOffset: \(cacheOffset), cacheLength: \(cacheLength)")
        /// 读取到缓存数据
        if cacheLength > 0 {
            /// 存在后面的缓存数据
            if cacheOffset > currentOffset {
                devPrint("网络层：存在后面的缓存数据")
                requestDataFromNetwork(offset: currentOffset, length: cacheOffset - currentOffset)
            }
            /// 存在缓存数据
            else if cacheOffset == currentOffset {
                devPrint("网络层：存在缓存数据")
                requestDataFromCache(offset: cacheOffset, length: cacheLength)
            }
            /// 缓存解析出错，走网络请求
            else {
                devPrint("网络层：缓存解析出错，走网络请求")
                requestDataFromNetwork(offset: currentOffset, length: offset + length - currentOffset)
            }
        }
        /// 当前数据段不存在缓存
        else {
            devPrint("网络层：当前数据段不存在缓存")
            requestDataFromNetwork(offset: currentOffset, length: offset + length - currentOffset)
        }
    }
    
    private func requestDataFromCache(offset: UInt64, length: UInt64) {
        devPrint("网络层：开始从缓存中读取数据offset：\(offset), length: \(length)")
        let coffset = currentOffset
        cache.readData(offset: offset, length: length, onQueue: operationQueue) { [weak self] (d) in
            devPrint("网络层：从缓存获取到数据offset: \(self?.currentOffset), length: \(d.count)")
            self?.dataBlock?(d)
            self?.currentOffset += UInt64(d.count)
        } complete: { [weak self] (error) in
            guard let self else {
                return
            }
            devPrint("网络层：从缓存获取到数据完成error: \(error)")
            if error == nil, self.currentOffset > coffset {
                self.checkDataSourcePosition()
            } else {
                self.requestDataFromNetwork(offset: offset, length: length)
            }
        }
    }
    
    private func requestDataFromNetwork(offset: UInt64, length: UInt64) {
        guard offset + length <= self.offset + self.length else {
            complete?(DataSourceError.network)
            devPrint("网络层：offset: \(offset), length: \(length), request offset: \(self.offset), length: \(self.length) 数据错误！！！！！！")
            return
        }
        devPrint("网络层：开始从网络获取到数据offset: \(offset), length: \(length)")
        currentTask?.cancel()
        currentTask = nil
        let task = DataSourceRequestTask(session: session, url: url, offset: offset, length: length, response: nil) { [weak self] (o, d) in
            guard let self else { return }
            self.dataBlock?(d)
            if self.currentOffset != o {
                devPrint("网络层：缓存写入错误 currentOffset: \(self.currentOffset), o: \(o)")
            }
            self.cache.writeData(d, offset: o, complete: nil)
            self.currentOffset += UInt64(d.count)
            devPrint("网络层：从网络获取到数据offset: \(o), length: \(d.count)")
        } complete: { [weak self] (error) in
            self?.currentTask = nil
            devPrint("网络层：从网络获取到数据完成error: \(error)")
            if let error {
                self?.complete?(error)
            } else {
                self?.checkDataSourcePosition()
            }
        }
        task.resume()
        currentTask = task
    }
}
