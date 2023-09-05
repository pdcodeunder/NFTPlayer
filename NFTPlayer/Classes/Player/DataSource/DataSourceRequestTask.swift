//
//  DataSourceRequestTask.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/9/1.
//

import Foundation

// MARK: - 一个网络请求对应一个task
class DataSourceRequestTask: Equatable {
    static func == (lhs: DataSourceRequestTask, rhs: DataSourceRequestTask) -> Bool {
        return lhs.task?.taskIdentifier == rhs.task?.taskIdentifier
    }
    
    let url: URL
    let task: URLSessionTask?
    let response: ((URLResponse?, UInt64, String?) -> Void)?
    let data: ((UInt64, Data) -> Void)?
    let complete: ((DataSourceError?) -> Void)?
    var isFinish = false
    var offset: UInt64 = 0
    var length: UInt64
    var receiveOffset: UInt64 = 0
    
    deinit {
        task?.cancel()
    }
    
    init(session: URLSession?, url: URL, offset: UInt64, length: UInt64, response: ((URLResponse?, UInt64, String?) -> Void)?, data: ((UInt64, Data) -> Void)?, complete: ((DataSourceError?) -> Void)?) {
        self.url = url
        self.response = response
        self.data = data
        self.complete = complete
        self.length = length
        self.offset = offset
        receiveOffset = offset
        var timeOut: TimeInterval = 0
        if length <= 16384 {
            timeOut = 5
        } else if length <= 1024 * 1024 {
            timeOut = 15
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeOut)
        request.addValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        task = session?.dataTask(with: request)
    }
    
    func resume() {
        receiveOffset = offset
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        var length: UInt64 = 0
        if let httpResponse = response as? HTTPURLResponse {
            let header = httpResponse.allHeaderFields
            let content: String?
            if let str = header["Content-Range"] as? String {
                content = str
            } else if let str = header["content-range"] as? String {
                content = str
            } else {
                content = nil
            }
            if let arr = content?.components(separatedBy: "/"), let lengthStr = arr.last {
                let videoLength: UInt64
                if let requestLength = UInt64(lengthStr) {
                    videoLength = requestLength
                } else {
                    videoLength = UInt64(httpResponse.expectedContentLength)
                }
                length = videoLength
            }
        }
        if self.offset + self.length > length {
            self.length = length - self.offset
        }
        self.response?(response, length, response.mimeType)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data?(receiveOffset, data)
        let count = UInt64(data.count)
        receiveOffset += count
        if receiveOffset == offset + length {
            isFinish = true
            complete?(nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isFinish else {
            return
        }
        if let _ = error {
            complete?(DataSourceError.network)
        } else {
            complete?(nil)
        }
    }
}
