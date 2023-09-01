//
//  PlayerUtil.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/28.
//

import Foundation
import UIKit
import CommonCrypto

func devPrint(_ items: Any...) {
    #if DEBUG
    print(items)
    #endif
}

extension UIImage {
    convenience init?(playerImageName name: String) {
        let bundle = Bundle(for: PlayerUtil.self)
        self.init(named: name, in: bundle, compatibleWith: nil)
    }
}

class PlayerUtil {
    static func doInMainThread(_ block: @escaping (() -> Void)) {
        if Thread.isMainThread { block() }
        else { DispatchQueue.main.async { block() } }
    }
    
    static var appIsActive: Bool {
        var isActive = true
        if #available(iOS 13.0, *) {
            if UIApplication.shared.connectedScenes.first?.activationState == .background {
                isActive = false
            }
        } else if UIApplication.shared.applicationState == .background {
            isActive = false
        }
        return isActive
    }
    
    static func md5(_ string: String) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        if let d = string.data(using: .utf8) {
            _ = d.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(d.count), &digest)
                return ""
            }
        }
        return (0 ..< length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }
    
    static func cacheRootPath() -> String? {
        let documentPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,
                                                                FileManager.SearchPathDomainMask.userDomainMask, true)
        let documnetPath = documentPaths.first
        return documnetPath
    }
}
