//
//  VideoRenderView.swift
//  Pods
//
//  Created by 彭懂 on 2023/8/25.
//

import Foundation
import AVFoundation

class VideoRenderView: UIView {
    init(frame: CGRect, player: AVPlayer) {
        super.init(frame: frame)
        self.player = player
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var isReadyForDisplay: Bool {
        guard let playerLayer = layer as? AVPlayerLayer else {
            assert(false, "isReadyForDisplay: VideoRenderView layer is not AVPlayerLayer")
            return false
        }
        return playerLayer.isReadyForDisplay
    }
    
    var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            guard let playerLayer = layer as? AVPlayerLayer else {
                assert(false, "scaleMode: VideoRenderView layer is not AVPlayerLayer")
                return
            }
            playerLayer.videoGravity = videoGravity
        }
    }
    
    var player: AVPlayer? {
        get {
            guard let playerLayer = layer as? AVPlayerLayer else {
                assert(false, "getplayer: VideoRenderView layer is not AVPlayerLayer")
                return nil
            }
            return playerLayer.player
        }
        set {
            guard let playerLayer = layer as? AVPlayerLayer else {
                assert(false, "setplayer: VideoRenderView layer is not AVPlayerLayer")
                return
            }
            playerLayer.videoGravity = videoGravity
            playerLayer.player = newValue
        }
    }
}
