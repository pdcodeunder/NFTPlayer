//
//  DataSourceOperation.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/31.
//

import Foundation

fileprivate protocol DataSourceTaskProtocol: AnyObject {
    var taskIdentifier: Int { get }
    var data: Data { get set }
    var isFinish: Bool { get set }
    
    func receive(data: Data)
    
    func complete()
}

class DataSourceOperation {
    class RequestTask: DataSourceTaskProtocol {
        var taskIdentifier: Int {
            return task.taskIdentifier
        }
        var data: Data = Data()
        var isFinish: Bool = false
        
        func receive(data: Data) {
            self.data.append(data)
        }
        
        func complete() {
            isFinish = true
        }
        
        let task: URLSessionTask
        
        init(task: URLSessionTask) {
            self.task = task
        }
    }
    
    class CacheTask: DataSourceTaskProtocol {
        var taskIdentifier: Int {
            return -1111221121
        }
        var data: Data
        var isFinish: Bool = true
        
        func receive(data: Data) {
            
        }
        
        func complete() {
            
        }
        
        init(data: Data) {
            self.data = data
        }
    }
    
    fileprivate
    class Operation {
        var taskList: [DataSourceTaskProtocol] = []
        
        let response: ((URLResponse) -> Void)?
        let data: ((Data) -> Void)?
        let complete: ((Error?) -> Void)?
        var offset: UInt64 = 0
        var length: UInt64 = 0
        
        init(response: ((URLResponse) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
            self.response = response
            self.data = data
            self.complete = complete
        }
        
        func appendTask(_ task: DataSourceTaskProtocol) {
            taskList.append(task)
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            
        }
    }
    
    private let session: URLSession?
    private let url: URL
    private let cache: DataSourceCache
    private var taskSet: [Operation] = []
    
    init(session: URLSession?, url: URL) {
        self.session = session
        self.url = url
        self.cache = DataSourceCache(url: url)
    }
    
    func obtainData(offset: UInt64, length: UInt64, response: ((URLResponse) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        cache.readData(offset: offset, length: length) { [weak self] (list) in
            self?.analysisCacheListAndRequest(list: list, offset: offset, length: length, response: response, data: data, complete: complete)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
    }
}

extension DataSourceOperation {
    private func analysisCacheListAndRequest(list: [(UInt64, Data)], offset: UInt64, length: UInt64, response: ((URLResponse) -> Void)?, data: ((Data) -> Void)?, complete: ((Error?) -> Void)?) {
        if list.isEmpty {
//            createRequestTask(offset: offset, length: length, response: response, data: data, complete: complete)
        } else {
            var currentOffset = offset
            list.forEach { item in
                let cacheOffset = item.0
                let cacheData = item.1
                
            }
        }
    }
    
    private func createRequestTask(offset: UInt64, length: UInt64) {
        
    }
}
