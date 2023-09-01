//
//  DataSourceOperation.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/31.
//

import Foundation
import AVFoundation

fileprivate class OperationTask: Equatable {
    static func == (lhs: OperationTask, rhs: OperationTask) -> Bool {
        return lhs.task.taskIdentifier == rhs.task.taskIdentifier
    }
    
    var task: URLSessionTask
    let response: ((URLResponse?, UInt64, String?) -> Void)?
    let data: ((UInt64, Data) -> Void)?
    let complete: ((DataSourceError?) -> Void)?
    var offset: UInt64 = 0 {
        didSet {
            receiveOffset = offset
        }
    }
    var length: UInt64 = 0
    var receiveOffset: UInt64 = 0
    var loadingRequest: AVAssetResourceLoadingRequest?
    
    init(task: URLSessionTask, response: ((URLResponse?, UInt64, String?) -> Void)?, data: ((UInt64, Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        self.task = task
        self.response = response
        self.data = data
        self.complete = complete
    }
    
    func resume() {
        task.resume()
    }
    
    func cancel() {
        task.cancel()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("-----: didReceive response")
        if let _ = loadingRequest?.contentInformationRequest {
            var length: UInt64 = 0
            if let httpResponse = response as? HTTPURLResponse {
                let header = httpResponse.allHeaderFields
                let content = header["Content-Range"] as? String
                if let arr = content?.components(separatedBy: "/"), let lengthStr = arr.last {
                    let videoLength: UInt64
                    if let requestLength = UInt64(lengthStr) {
                        videoLength = requestLength
                    } else {
                        videoLength = UInt64(httpResponse.expectedContentLength)
                    }
                    print("------- video length: \(videoLength)")
                    length = videoLength
                }
            }
            self.response?(response, length, response.mimeType)
        }
        completionHandler(.allow)
//        complete?(DataSourceError.network)
//        completionHandler(.cancel)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let _ = loadingRequest?.dataRequest {
            self.data?(receiveOffset, data)
            let count = UInt64(data.count)
            receiveOffset += count
            if receiveOffset == offset + length {
                complete?(nil)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("-----didCompleteWithError: \(error)")
        if let _ = error {
            complete?(DataSourceError.network)
        } else if let _ = loadingRequest?.dataRequest {
            if receiveOffset == offset + length {
                complete?(nil)
            } else {
                complete?(DataSourceError.network)
            }
        } else {
            complete?(nil)
        }
    }
}

class DataSourceOperation {
    private let session: URLSession?
    private let url: URL
    private let cache: DataSourceCache
    private let operationQueue: DispatchQueue
    private var operationSet: [Int: OperationTask] = [:]
    
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
        operationSet.values.forEach({ $0.cancel() })
        operationSet = [:]
    }
    
    func cancelLoadingRequest(_ request: AVAssetResourceLoadingRequest) {
        let map = operationSet
        map.forEach { item in
            let key = item.key
            let op = item.value
            if op.loadingRequest == request {
                op.cancel()
                operationSet.removeValue(forKey: key)
            }
        }
    }
    
    func obtainData(for loadingRequest: AVAssetResourceLoadingRequest, response: ((URLResponse?, UInt64, String?) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        if let _ = loadingRequest.contentInformationRequest {
            if cache.videoLength > 0 {
                response?(nil, cache.videoLength, cache.mimeType)
                complete?(nil)
            } else {
                createRequest(for: loadingRequest, offset: 0, length: 2, response: response, data: data, complete: complete)
            }
        } else if let dataRequest = loadingRequest.dataRequest {
            let offset = UInt64(dataRequest.currentOffset)
            let length = UInt64(dataRequest.requestedLength) - UInt64(dataRequest.currentOffset - dataRequest.requestedOffset)
            print("------offset: \(offset), length: \(length)")
            cache.readData(offset: offset, length: length, data: data, complete: { [weak self] (error) in
                if let error {
                    switch error {
                    case .noCache:
                        self?.createRequest(for: loadingRequest, offset: offset, length: length, response: response, data: data, complete: complete)
                    default:
                        complete?(error)
                    }
                } else {
                    complete?(nil)
                }
            })
        } else {
            complete?(DataSourceError.requestIsEmpty)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let operation = operationSet[dataTask.taskIdentifier] {
            operation.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let operation = operationSet[dataTask.taskIdentifier] {
            operation.urlSession(session, dataTask: dataTask, didReceive: data)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let operation = operationSet[task.taskIdentifier] {
            operation.urlSession(session, task: task, didCompleteWithError: error)
        }
    }
}

extension DataSourceOperation {
    private func createRequest(for loadingRequest: AVAssetResourceLoadingRequest?, offset: UInt64, length: UInt64, response: ((URLResponse?, UInt64, String?) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        operationQueue.async { [weak self] in
            self?.realCreateRequest(for: loadingRequest, offset: offset, length: length, response: response, data: data, complete: complete)
        }
    }
    
    private func realCreateRequest(for loadingRequest: AVAssetResourceLoadingRequest?, offset: UInt64, length: UInt64, response: ((URLResponse?, UInt64, String?) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        guard let session else {
            complete?(DataSourceError.network)
            return
        }
        var timeOut: TimeInterval = 0
        if length <= 16384 {
            timeOut = 5
        } else if length <= 1024 * 1024 {
            timeOut = 15
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeOut)
        request.addValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        let task = session.dataTask(with: request)
        let operation = OperationTask(task: task, response: { [weak self] (r, l, m) in
            if let _ = loadingRequest?.contentInformationRequest {
                self?.cache.videoLength = l
                self?.cache.mimeType = m
                response?(r, l, m)
            }
        }, data: { [weak self] (cacheOffset, responceData) in
            if loadingRequest?.contentInformationRequest == nil {
                self?.cache.writeData(responceData, offset: cacheOffset, complete: nil)
                data?(responceData)
            }
        }, complete: { [weak self] (error) in
            self?.operationSet.removeValue(forKey: task.taskIdentifier)
            complete?(error)
        })
        operation.offset = offset
        operation.length = length
        operation.loadingRequest = loadingRequest
        operationSet[task.taskIdentifier] = operation
        operation.resume()
    }
}
