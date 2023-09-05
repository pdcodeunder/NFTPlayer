//
//  MediaConvertible.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/28.
//

import Foundation

public protocol MediaConvertible {
    /// 视频url
    func urls() -> [URL]
    /// 对比是否同一个数据源
    func isEqualTo(_ other: MediaConvertible) -> Bool
}

extension MediaConvertible {
    /// 对比是否同一个数据源
    public func isEqualTo(_ other: MediaConvertible) -> Bool {
        return urls() == other.urls()
    }
}


extension String: MediaConvertible {
    public func urls() -> [URL] {
        guard let url = URL(string: self) else {
            return []
        }
        return [url]
    }
}

extension URL: MediaConvertible {
    public func urls() -> [URL] {
        [self]
    }
}

extension Array: MediaConvertible where Element == URL {
    public func urls() -> [URL] {
        return self
    }
}
