//
//  DataSourceCenter.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/29.
//

import Foundation
import AVFoundation

class DataSourceCenter: NSObject {
    static let shared = DataSourceCenter()
    private var operationMap: [URL: DataSourceUrlOperation] = [:]
    private let handleQueue = DispatchQueue(label: "com.player.operation.handleQueue")
    private var session: URLSession?
    
    func obtainContentInformation(url: URL, identifer: AnyObject, complete: ((URLResponse?, UInt64, String?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalObtainContentInformation(url: url, identifer: identifer, complete: complete)
        }
    }
    
    func obtainData(url: URL, loadingRequest: AVAssetResourceLoadingRequest, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        handleQueue.async { [weak self] in
            self?.internalObtainData(url: url, loadingRequest: loadingRequest, data: data, complete: complete)
        }
    }
    
    func cancelRequest(url: URL) {
        handleQueue.async {
            self.internalCancelRequest(url: url)
        }
    }
    
    func cancelAssetLoadingRequest(url: URL, _ request: AVAssetResourceLoadingRequest) {
        handleQueue.async {
            self.internalCancelAssetLoadingRequest(url: url, request)
        }
    }
}

extension DataSourceCenter {
    private func internalObtainContentInformation(url: URL, identifer: AnyObject, complete: ((URLResponse?, UInt64, String?) -> Void)?) {
        createSession()
        let operation = obtainOperation(url: url)
        operation.obtainContentInformation(identifer: identifer) { (r, l, m) in
            PlayerUtil.doInMainThread {
                complete?(r, l, m)
            }
        }
    }
    
    private func internalObtainData(url: URL, loadingRequest: AVAssetResourceLoadingRequest, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        createSession()
        let operation = obtainOperation(url: url)
        operation.obtainData(for: loadingRequest, data: { d in
            PlayerUtil.doInMainThread {
                data?(d)
            }
        }, complete: { e in
            PlayerUtil.doInMainThread {
                complete?(e)
            }
        })
    }
    
    private func internalCancelRequest(url: URL) {
        if let op = operationMap.removeValue(forKey: url) {
            op.cancelAll()
        }
    }
    
    private func internalCancelAssetLoadingRequest(url: URL, _ request: AVAssetResourceLoadingRequest) {
        if let op = operationMap[url] {
            op.cancelLoadingRequest(request)
        }
    }
    
    private func createSession() {
        guard session == nil else {
            return
        }
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpShouldUsePipelining = false
        config.networkServiceType = .video
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.allowsCellularAccess = true
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = handleQueue
        delegateQueue.name = "com.player.operation.sessionDelegateQueue"
        session = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
    }
    
    private func obtainOperation(url: URL) -> DataSourceUrlOperation {
        if let operation = operationMap[url] {
            return operation
        }
        let operation = DataSourceUrlOperation(session: session, url: url, queue: handleQueue)
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

extension DataSourceCenter {
    func preload(url: URL, offset: UInt64, length: UInt64) {
        handleQueue.async { [weak self] in
            self?.internalPreload(url: url, offset: offset, length: length)
        }
    }
    
    private func internalPreload(url: URL, offset: UInt64, length: UInt64) {
        if let _ = operationMap[url] {
            return
        }
        createSession()
        let operation = obtainOperation(url: url)
        operation.preload(offset: offset, length: length)
    }
}
