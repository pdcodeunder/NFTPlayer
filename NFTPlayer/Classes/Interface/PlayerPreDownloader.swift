//
//  PlayerPreDownloader.swift
//  Pods
//
//  Created by 彭懂 on 2023/8/25.
//

import Foundation

public
class PlayerPreDownloader {
    
    public
    static func preload(urls: [URL], length: UInt64) {
        urls.forEach({ DataSourceCenter.shared.preload(url: $0, offset: 0, length: length) })
    }
    
    public
    static func preload(url: URL, length: UInt64) {
        DataSourceCenter.shared.preload(url: url, offset: 0, length: length)
    }
}
