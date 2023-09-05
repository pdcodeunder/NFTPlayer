//
//  PlayerManager.swift
//  Pods
//
//  Created by 彭懂 on 2023/8/25.
//

import Foundation

/// 播放状态
public
enum PlayStatus {
    case initialize
    case ready
    case playing
    case seeking
    case stalled
    case pause
    case failed
    case end
}

// MARK: -
public protocol PlayerManagerProtocol: AnyObject {
    /// 每次调用play(media:to:)方法对应的唯一出口
    func playerFinish(media: MediaConvertible)
    /// 当前播放状态改变
    func playerPlayStatusChanged(media: MediaConvertible, status: PlayStatus)
    /// 当前播放进度
    func playerPlayDuration(media: MediaConvertible, duration: TimeInterval, currentTime: TimeInterval)
    /// 当前加载进度
    func playerLoadedTime(media: MediaConvertible, time: TimeInterval)
    /// 当前播放进度
    func playerRecordProgress(media: MediaConvertible) -> TimeInterval
}

extension PlayerManagerProtocol {
    func playerPlayStatusChanged(media: MediaConvertible, status: PlayStatus) {}
    func playerPlayDuration(media: MediaConvertible, duration: TimeInterval, currentTime: TimeInterval) {}
    func playerLoadedTime(media: MediaConvertible, time: TimeInterval) {}
    func playerRecordProgress(media: MediaConvertible) -> TimeInterval { return 0 }
}

// MARK: - 视频播放资源，不对外开放
class PlayerSource {
    weak var delegate: PlayerManagerProtocol?
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
    
    deinit {
        delegate?.playerFinish(media: media)
    }
    
    func changeNextUrl() -> URL? {
        currentIndex += 1
        return currentUrl
    }
    
    /// 当前播放状态改变
    func playerPlayStatusChanged(status: PlayStatus) {
        delegate?.playerPlayStatusChanged(media: media, status: status)
    }
    /// 当前播放进度
    func playerPlayDuration(_ duration: TimeInterval, currentTime: TimeInterval) {
        delegate?.playerPlayDuration(media: media, duration: duration, currentTime: currentTime)
    }
    /// 当前加载进度
    func playerLoadedTime(_ time: TimeInterval) {
        delegate?.playerLoadedTime(media: media, time: time)
    }
    /// 当前播放进度
    func playerRecordProgress() -> TimeInterval {
        return delegate?.playerRecordProgress(media: media) ?? 0
    }
}

// MARK: - 视频播放管理类
public class PlayerManager {
    public static let shared = PlayerManager()
    private var interfaceView: PlayerInterfaceViewProtocol = PlayerInterfaceDefaultView()
    private var source: PlayerSource?
    private var player: VideoPlayer?
    public var currentMedia: MediaConvertible? {
        return source?.media
    }
    /// 绑定视频播放交互控件
    public
    func bindInterfaceControl(view: PlayerInterfaceViewProtocol) {
        interfaceView.removeFromSuperview()
        interfaceView = view
        player?.videoView.addSubview(view)
    }
    /// 播放视频
    public func play(media: MediaConvertible, to containerView: UIView, delegate: PlayerManagerProtocol?) {
        /// 如果是同一个播放源，则只需要切换containerView
        if let source, source.media.isEqualTo(media) {
            source.delegate = delegate
            source.media = media
            changeContainerView(to: containerView)
            return
        }
        source = nil
        player?.pause()
        player = nil
        let s = PlayerSource(media: media)
        s.delegate = delegate
        source = s
        guard let url = s.currentUrl else {
            source = nil
            return
        }
        internalPlay(url: url, containerView: containerView)
    }
    /// 改变视频播放视图容器
    public func changeContainerView(to view: UIView) {
        guard let player else {
            return
        }
        player.play(to: view)
        interfaceView.frame = player.videoView.bounds
        player.videoView.addSubview(interfaceView)
    }
    /// 播放
    public func play() {
        player?.play()
    }
    /// 停止
    public func stop() {
        player?.pause()
        player = nil
        interfaceView.removeFromSuperview()
        source = nil
    }
    /// 暂停
    public func pause() {
        player?.pause()
    }
    /// 滑动
    public func seek(time: TimeInterval) {
        player?.seekTo(time: time)
    }
}

extension PlayerManager {
    private func internalPlay(url: URL, containerView: UIView) {
        player?.pause()
        player = nil
        let p = VideoPlayer(url: url, delegate: self)
        p.play(to: containerView)
        interfaceView.frame = p.videoView.bounds
        interfaceView.currentTime = 0
        interfaceView.loadedTime = 0
        interfaceView.duration = 0
        p.videoView.addSubview(interfaceView)
        player = p
    }
    
    private func changeSourceUrlPlay() {
        guard let url = source?.changeNextUrl(), let containerView = player?.videoView.superview else {
            source?.playerPlayStatusChanged(status: .failed)
            interfaceView.isPause = true
            return
        }
        internalPlay(url: url, containerView: containerView)
    }
}

extension PlayerManager: VideoPlayerDelegate {
    func videoPlayerPlayStatusChanged(player: VideoPlayer, status: PlayStatus) {
        if status != .failed {
            source?.playerPlayStatusChanged(status: status)
        }
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
            changeSourceUrlPlay()
        case .end:
            interfaceView.isPause = true
        }
    }
    
    func videoPlayerPlayDuration(player: VideoPlayer, duration: TimeInterval, currentTime: TimeInterval) {
        interfaceView.duration = duration
        interfaceView.currentTime = currentTime
        source?.playerPlayDuration(duration, currentTime: currentTime)
    }
    
    func videoPlayerLoadedTime(player: VideoPlayer, time: TimeInterval) {
        interfaceView.loadedTime = time
        source?.playerLoadedTime(time)
    }
    
    func videoPlayerRecordProgress(player: VideoPlayer) -> TimeInterval {
        return source?.playerRecordProgress() ?? 0
    }
    
}
