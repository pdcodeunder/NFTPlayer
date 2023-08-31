//
//  PlayerManager.swift
//  Pods
//
//  Created by 彭懂 on 2023/8/25.
//

import Foundation

public
enum PlayerError: Error {
    /// url 错误
    case errorUrl
    /// 停止
    case stop
}

public protocol PlayerManagerProtocol: AnyObject {
    /// 每次调用play(media:to:)方法对应的唯一出口
    func playerFinish(media: MediaConvertible, error: PlayerError?)
}

class PlayerSource {
    var currentIndex = 0
    var media: MediaConvertible
    var currentUrl: URL? {
        let urls = media.urls()
        if urls.count > currentIndex {
            return urls[currentIndex]
        }
        return nil
    }
    
    init(media: MediaConvertible) {
        self.media = media
    }
}

public class PlayerManager {
    public static let shared = PlayerManager()
    private var interfaceView: PlayerInterfaceViewProtocol = PlayerInterfaceDefaultView()
    private var source: PlayerSource?
    private var player: VideoPlayer?
    weak var delegate: PlayerManagerProtocol?
    
    public
    func bindInterfaceControl(view: PlayerInterfaceViewProtocol) {
        interfaceView.removeFromSuperview()
        interfaceView = view
        player?.videoView.addSubview(view)
    }
    
    public func play(media: MediaConvertible, to containerView: UIView) {
        if let source {
            delegate?.playerFinish(media: source.media, error: nil)
        }
        source = nil
        player?.pause()
        player = nil
        let s = PlayerSource(media: media)
        guard let url = s.currentUrl else {
            delegate?.playerFinish(media: media, error: .errorUrl)
            return
        }
        source = s
        let p = VideoPlayer(url: url, delegate: self)
        p.play(to: containerView)
        interfaceView.frame = p.videoView.bounds
        p.videoView.addSubview(interfaceView)
        player = p
    }
    
    public func play() {
        player?.play()
    }
    
    public func stop() {
        if let source {
            delegate?.playerFinish(media: source.media, error: .stop)
        }
        player?.pause()
        player = nil
        interfaceView.removeFromSuperview()
        source = nil
    }
    
    public func pause() {
        player?.pause()
    }
    
    public func seek(time: TimeInterval) {
        player?.seekTo(time: time)
    }
}

extension PlayerManager: VideoPlayerDelegate {
    func videoPlayerPlayStatusChanged(player: VideoPlayer, status: VideoPlayer.PlayStatus) {
        switch status {
        case .initialize:
            interfaceView.isLoading = true
        case .ready:
            interfaceView.isLoading = false
        case .playing:
            interfaceView.isLoading = false
            interfaceView.isPause = false
        case .seeking:
            interfaceView.isLoading = true
        case .stalled:
            interfaceView.isLoading = true
        case .pause:
            interfaceView.isPause = true
        case .failed:
            interfaceView.isPause = true
        case .end:
            interfaceView.isPause = true
        }
    }
    
    func videoPlayerPlayDuration(player: VideoPlayer, duration: TimeInterval, currentTime: TimeInterval) {
        interfaceView.duration = duration
        interfaceView.currentTime = currentTime
    }
    
    func videoPlayerLoadedTime(player: VideoPlayer, time: TimeInterval) {
        interfaceView.loadedTime = time
    }
    
    func videoPlayerRecordProgress(player: VideoPlayer) -> TimeInterval {
        return 0
    }
    
}
