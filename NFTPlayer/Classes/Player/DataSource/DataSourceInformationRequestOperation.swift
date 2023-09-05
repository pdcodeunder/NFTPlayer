//
//  DataSourceInformationRequestOperation.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/9/4.
//

import Foundation

// MARK: - 视频播放一个InformationRequest对应一个DataSourceDataRequestOperation，用于管理与当前InformationRequest相关的请求的
class DataSourceInformationRequestOperation: DataSourceRequestOperationProtocol {
    let session: URLSession?
    let cache: DataSourceCache
    let url: URL
    let requestIdentifer: AnyObject
    let responseBlock: ((URLResponse?, UInt64, String?) -> Void)?
    let operationQueue: DispatchQueue
    var currentTask: DataSourceRequestTask?

    init(session: URLSession?, cache: DataSourceCache, url: URL, requestIdentifer: AnyObject, responseBlock: ((URLResponse?, UInt64, String?) -> Void)?, operationQueue: DispatchQueue) {
        self.session = session
        self.cache = cache
        self.url = url
        self.requestIdentifer = requestIdentifer
        self.responseBlock = responseBlock
        self.operationQueue = operationQueue
    }
    
    func resume() {
        let task = DataSourceRequestTask(session: session, url: url, offset: 0, length: 2, response: { [weak self] (response, length, mimeType) in
            self?.cache.updateVideoLength(length, mimeType: mimeType)
            self?.responseBlock?(response, length, mimeType)
        }, data: nil, complete: { [weak self] (error) in
            if let _ = error {
                self?.responseBlock?(nil, 0, nil)
            }
        })
        task.resume()
        currentTask = task
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
