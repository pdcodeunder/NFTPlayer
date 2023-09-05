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
    var length: UInt64
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
        guard currentOffset < offset + length else {
            complete?(nil)
            return
        }
        
        cache.findData(offset: currentOffset, length: offset + length - currentOffset, onQueue: operationQueue) { [weak self] (cacheOffset, cacheLength) in
            self?.findDataFromCacheResponse(cacheOffset: cacheOffset, cacheLength: cacheLength)
        }
    }
    
    private func findDataFromCacheResponse(cacheOffset: UInt64, cacheLength: UInt64) {
        /// 读取到缓存数据
        if cacheLength > 0 {
            /// 存在后面的缓存数据
            if cacheOffset > currentOffset {
                requestDataFromNetwork(offset: currentOffset, length: cacheOffset - currentOffset)
            }
            /// 存在缓存数据
            else if cacheOffset == currentOffset {
                requestDataFromCache(offset: cacheOffset, length: cacheLength)
            }
            /// 缓存解析出错，走网络请求
            else {
                requestDataFromNetwork(offset: currentOffset, length: offset + length - currentOffset)
            }
        }
        /// 当前数据段不存在缓存
        else {
            requestDataFromNetwork(offset: currentOffset, length: offset + length - currentOffset)
        }
    }
    
    private func requestDataFromCache(offset: UInt64, length: UInt64) {
        let coffset = currentOffset
        cache.readData(offset: offset, length: length, onQueue: operationQueue) { [weak self] (d) in
            self?.dataBlock?(d)
            self?.currentOffset += UInt64(d.count)
        } complete: { [weak self] (error) in
            guard let self else {
                return
            }
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
            return
        }
        currentTask?.cancel()
        currentTask = nil
        let task = DataSourceRequestTask(session: session, url: url, offset: offset, length: length, response: { [weak self] (_, videoLength, _) in
            guard let self else { return }
            if self.offset + self.length > videoLength {
                self.length = videoLength - self.offset
            }
        }, data: { [weak self] (o, d) in
            guard let self else { return }
            self.dataBlock?(d)
            self.cache.writeData(d, offset: o, complete: nil)
            self.currentOffset += UInt64(d.count)
        }, complete: { [weak self] (error) in
            self?.currentTask = nil
            if let error {
                self?.complete?(error)
            } else {
                self?.checkDataSourcePosition()
            }
        })
        task.resume()
        currentTask = task
    }
}

// MARK: - 预加载
extension DataSourceDataRequestOperation {
    func preload() {
        cache.findData(offset: offset, length: length, onQueue: operationQueue) { [weak self] (cacheOffset, cacheLength) in
            if cacheLength > 0 {
                self?.complete?(nil)
            } else {
                self?.preloadFromNetwork()
            }
        }
    }
    
    private func preloadFromNetwork() {
        currentTask?.cancel()
        currentTask = nil
        let task = DataSourceRequestTask(session: session, url: url, offset: offset, length: length, response: { [weak self] (response, videoLength, mimeType) in
            guard let self else { return }
            if self.offset + self.length > videoLength {
                self.length = videoLength - self.offset
            }
            if videoLength > 0 {
                self.cache.updateVideoLength(videoLength, mimeType: mimeType)
            }
        }, data: { [weak self] (o, d) in
            guard let self else { return }
            self.dataBlock?(d)
            self.cache.writeData(d, offset: o, complete: nil)
            self.currentOffset += UInt64(d.count)
        }, complete: { [weak self] (error) in
            self?.currentTask = nil
            if let error {
                self?.complete?(error)
            } else {
                self?.checkDataSourcePosition()
            }
        })
        task.resume()
        currentTask = task
    }
}
