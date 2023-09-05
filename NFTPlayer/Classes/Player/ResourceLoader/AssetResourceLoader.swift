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
    
    init(url: URL) {
        self.url = url
        DataSourceCenter.shared.cancelRequest(url: url)
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
        request.contentInformationRequest?.isByteRangeAccessSupported = true
        if let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil) {
            let contentTypeStr = contentType.takeRetainedValue() as String
            request.contentInformationRequest?.contentType = convertTypeIfNeeded(contentType: contentTypeStr)
        }
        request.contentInformationRequest?.contentLength = Int64(length)
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
        /// 请求视频信息
        if let _ = loadingRequest.contentInformationRequest {
            DataSourceCenter.shared.obtainContentInformation(url: url, identifer: loadingRequest, complete: { [weak self] (response, length, mimeType) in
                guard self?.checkLoadingRequestIsValid(request: loadingRequest) == true else { return }
                if length > 0 {
                    self?.fillInfoRequest(request: loadingRequest, response: response, length: length, mimeType: mimeType ?? "video/mp4")
                    loadingRequest.finishLoading()
                } else {
                    loadingRequest.finishLoading(with: NSError(domain: "数据请求失败", code: 404))
                }
            })
            return true
        }
        /// 请求视频数据
        else if let _ = loadingRequest.dataRequest {
            DataSourceCenter.shared.obtainData(url: url, loadingRequest: loadingRequest, data: { [weak self] (data) in
                guard self?.checkLoadingRequestIsValid(request: loadingRequest) == true else { return }
                loadingRequest.dataRequest?.respond(with: data)
            }, complete: { [weak self] (error) in
                guard self?.checkLoadingRequestIsValid(request: loadingRequest) == true else { return }
                if let _ = error {
                    loadingRequest.finishLoading(with: NSError(domain: "数据请求失败", code: 500))
                } else {
                    loadingRequest.finishLoading()
                }
            })
            return true
        }
        /// 不识别请求，丢弃
        loadingRequest.finishLoading(with: NSError(domain: "不识别请求，丢弃", code: 404))
        return false
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        DataSourceCenter.shared.cancelAssetLoadingRequest(url: url, loadingRequest)
    }
}
