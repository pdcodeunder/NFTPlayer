//
//  AssetResourceLoader.swift
//  Pods
//
//  Created by 彭懂 on 2023/8/25.
//

import Foundation
import AVFoundation
import CoreServices

class AssetResourceLoader: NSObject {
    let url: URL
    var paserResponse = false
    
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        DataSourceCenter.shared.cancelRequest(url: url)
    }
    
    var playerUrl: URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "nftplayer"
        return components?.url
    }
    
    func cancel() {
        DataSourceCenter.shared.cancelRequest(url: url)
    }
}

extension AssetResourceLoader {
    /// 根据请求响应修改对应request
    private func fillInfoRequest(request: AVAssetResourceLoadingRequest, response: URLResponse?, length: UInt64, mimeType: String) {
        func convertTypeIfNeeded(contentType: String) -> String {
            if contentType == "public.text" || contentType == "public.plain-text" {
                return "public.mpeg-4"
            }
            return contentType
        }
        paserResponse = true
        devPrint("处理SourceCenter响应 length: \(length), mimeType: \(mimeType)")
        request.contentInformationRequest?.isByteRangeAccessSupported = true
        if let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil) {
            let contentTypeStr = contentType.takeRetainedValue() as String
            request.contentInformationRequest?.contentType = convertTypeIfNeeded(contentType: contentTypeStr)
        }
        request.contentInformationRequest?.contentLength = Int64(length)
        devPrint("处理SourceCenter响应完成:\(request)")
    }
    
    /// 校验loadingRequest的有效性
    private func checkLoadingRequestIsValid(request: AVAssetResourceLoadingRequest) -> Bool {
        if request.isCancelled || request.isFinished {
            return false
        }
        return true
    }
}

extension AssetResourceLoader: AVAssetResourceLoaderDelegate {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        devPrint("接收到ResourceLoader数据请求: \(loadingRequest)")
        DataSourceCenter.shared.obtainData(url: url, loadingRequest: loadingRequest) { [weak self] (responce, length, mimeType) in
            devPrint("接收到SourceCenter响应 length: \(length), mimeType: \(mimeType)")
            guard self?.checkLoadingRequestIsValid(request: loadingRequest) == true else { return }
            self?.fillInfoRequest(request: loadingRequest, response: responce, length: length, mimeType: mimeType ?? "video/mp4")
        } data: { [weak self] (data) in
            devPrint("接收到SourceCenter数据 data: \(data.count))")
            guard self?.checkLoadingRequestIsValid(request: loadingRequest) == true else { return }
            devPrint("填充SourceCenter数据 data: \(data.count))")
            loadingRequest.dataRequest?.respond(with: data)
        } complete: { [weak self] (error) in
            devPrint("接收到SourceCenter完成: \(error))")
            guard self?.checkLoadingRequestIsValid(request: loadingRequest) == true else { return }
            if let _ = error {
                devPrint("处理SourceCenter失败: \(error))")
                self?.paserResponse = false
                loadingRequest.finishLoading(with: NSError(domain: "数据请求失败", code: 404))
            } else {
                devPrint("处理SourceCenter完成")
                loadingRequest.finishLoading()
            }
        }
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        devPrint("接收到ResourceLoader取消请求: \(loadingRequest)")
        DataSourceCenter.shared.cancelAssetLoadingRequest(url: url, loadingRequest)
    }
}
