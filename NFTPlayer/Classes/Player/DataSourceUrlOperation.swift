//
//  DataSourceOperation.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/31.
//

import Foundation
import AVFoundation

protocol DataSourceRequestOperationProtocol {
    var requestIdentifer: AnyObject { get }
    
    func resume()
    
    func cancel()
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
}

// MARK: - 视频播放一个URL对应一个DataSourceUrlOperation，用于管理所有与当前URL相关的请求的
class DataSourceUrlOperation {
    private let session: URLSession?
    private let url: URL
    private let cache: DataSourceCache
    private let operationQueue: DispatchQueue
    private var operationSet: [DataSourceRequestOperationProtocol] = []
    
    init(session: URLSession?, url: URL, queue: DispatchQueue) {
        self.session = session
        self.url = url
        operationQueue = queue
        self.cache = DataSourceCache(url: url)
    }
    
    deinit {
        cancelAll()
    }
    
    func cancelAll() {
        let list = operationSet
        operationSet = []
        list.forEach({ $0.cancel() })
    }
    
    func cancelLoadingRequest(_ request: AVAssetResourceLoadingRequest) {
        devPrint("网络层：接收到取消指令：\(operationSet)")
        let list = operationSet.filter({ $0.requestIdentifer === request })
        operationSet.removeAll { item in
            if item.requestIdentifer === request {
                return true
            }
            return false
        }
        devPrint("网络层：operationSet移除完成：\(operationSet)")
        list.forEach({ $0.cancel() })
    }
    
    func obtainContentInformation(identifer: AnyObject, complete: ((URLResponse?, UInt64, String?) -> Void)?) {
        if cache.videoLength > 0 {
            complete?(nil, cache.videoLength, cache.mimeType)
        } else {
            let operation = DataSourceInformationRequestOperation(session: session, cache: cache, url: url, requestIdentifer: identifer, responseBlock: { [weak self] (response, length, mimeType) in
                self?.operationSet.removeAll(where: { item in
                    return item.requestIdentifer === identifer
                })
                complete?(response, length, mimeType)
            }, operationQueue: operationQueue)
            operation.resume()
            operationSet.append(operation)
        }
    }
    
    func obtainData(for loadingRequest: AVAssetResourceLoadingRequest, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        devPrint("网络层：开始获取视频数据")
        guard let dataRequest = loadingRequest.dataRequest else {
            complete?(DataSourceError.requestError)
            return
        }
        let offset = UInt64(dataRequest.currentOffset)
        let length = UInt64(dataRequest.requestedLength) - UInt64(dataRequest.currentOffset - dataRequest.requestedOffset)
        let operation = DataSourceDataRequestOperation(operationQueue: operationQueue, session: session, cache: cache, url: url, requestIdentifer: loadingRequest, offset: offset, length: length, dataBlock: data, complete: { [weak self] (error) in
            self?.operationSet.removeAll(where: { item in
                return item.requestIdentifer === dataRequest
            })
            complete?(error)
        })
        operation.resume()
        operationSet.append(operation)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        operationSet.forEach({ $0.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler) })
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        operationSet.forEach({ $0.urlSession(session, dataTask: dataTask, didReceive: data) })
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        operationSet.forEach({ $0.urlSession(session, task: task, didCompleteWithError: error) })
    }
}
