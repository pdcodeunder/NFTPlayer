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
