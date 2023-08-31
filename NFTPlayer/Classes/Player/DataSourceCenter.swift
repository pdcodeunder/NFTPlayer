//
//  DataSourceCenter.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/29.
//

import Foundation

class DataSourceCenter: NSObject {
    static let shared = DataSourceCenter()
    
    private var operationMap: [URL: DataSourceOperation] = [:]
    private let handleQueue = DispatchQueue(label: "com.player.operation.handleQueue")
    private var session: URLSession?
    
    func obtainData(url: URL, offset: UInt64, length: UInt64, response: ((URLResponse) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalObtainData(url: url, offset: offset, length: length, response: response, data: data, complete: complete)
        }
    }
}

extension DataSourceCenter {
    private func internalObtainData(url: URL, offset: UInt64, length: UInt64, response: ((URLResponse) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        createSession()
        let operation = obtainOperation(url: url)
        operation.obtainData(url: url, offset: offset, length: length, reponse: response, data: data, complete: complete)
    }
    
    private func createSession() {
        guard session == nil else {
            return
        }
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpShouldUsePipelining = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.allowsCellularAccess = true
        config.urlCache = nil
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = handleQueue
        delegateQueue.name = "com.player.operation.sessionDelegateQueue"
        session = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
    }
    
    private func obtainOperation(url: URL) -> DataSourceOperation {
        if let operation = operationMap[url] {
            return operation
        }
        let operation = DataSourceOperation(session: session, url: url)
        operationMap[url] = operation
        return operation
    }
}

extension DataSourceCenter: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let url = dataTask.originalRequest?.url else { return }
        let operation = obtainOperation(url: url)
        operation.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let url = dataTask.originalRequest?.url else { return }
        let operation = obtainOperation(url: url)
        operation.urlSession(session, dataTask: dataTask, didReceive: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else { return }
        let operation = obtainOperation(url: url)
        operation.urlSession(session, task: task, didCompleteWithError: error)
    }
}
