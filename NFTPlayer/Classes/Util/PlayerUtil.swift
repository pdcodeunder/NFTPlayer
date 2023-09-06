//
//  PlayerUtil.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/28.
//

import Foundation
import UIKit
import CryptoKit

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
        let messageData = string.data(using: .utf8)!
        let digestData = Insecure.MD5.hash (data: messageData)
        let digestHex = String(digestData.map { String(format: "%02hhx", $0) }.joined().prefix(32))
        return digestHex
    }
    
    static func cacheRootPath() -> String? {
        let documentPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,
                                                                FileManager.SearchPathDomainMask.userDomainMask, true)
        let documnetPath = documentPaths.first
        return documnetPath
    }
    
    static func freeDiskSpaceInBytes() -> Int64 {
        if #available(iOS 11.0, *) {
            if let space = try? URL(fileURLWithPath: NSHomeDirectory() as String).resourceValues(forKeys: [URLResourceKey.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
                return space
            } else {
                return 0
            }
        } else {
            if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
            let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value {
                return freeSpace
            } else {
                return 0
            }
        }
    }
    
    static func diskSpaceSize(for path: String) -> UInt64 {
        return folderSize(atPath: path)
    }
    
    private static func folderSize(atPath path: String) -> UInt64 {
        let fileManager = FileManager.default
        var size: UInt64 = 0
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // 如果是目录，递归计算子目录的大小
                        size += folderSize(atPath: itemPath)
                    } else {
                        // 如果是文件，获取文件大小并累加到总大小
                        if let fileSize = try? fileManager.attributesOfItem(atPath: itemPath)[.size] as? UInt64 {
                            size += fileSize
                        }
                    }
                }
            }
        } catch {
            print("Error: \(error)")
        }
        return size
    }
}
