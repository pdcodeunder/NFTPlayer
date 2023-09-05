//
//  VideoPlayer.swift
//  Pods
//
//  Created by 彭懂 on 2023/8/25.
//

import Foundation
import ObjectiveC
import AVFoundation
import CoreMedia

protocol VideoPlayerDelegate: AnyObject {
    /// 当前播放状态改变
    func videoPlayerPlayStatusChanged(player: VideoPlayer, status: PlayStatus)
    /// 当前播放进度
    func videoPlayerPlayDuration(player: VideoPlayer, duration: TimeInterval, currentTime: TimeInterval)
    /// 当前加载进度
    func videoPlayerLoadedTime(player: VideoPlayer, time: TimeInterval)
    /// 当前播放进度
    func videoPlayerRecordProgress(player: VideoPlayer) -> TimeInterval
}

class VideoPlayer: NSObject {
    /// 控制状态
    enum ControlStatus {
        case initialize
        case play
        case pause
        case failed
        case end
    }
    
    private let url: URL
    private let player: AVPlayer
    let videoView: VideoRenderView
    private let urlAsset: AVURLAsset
    private let playerItem: AVPlayerItem
    private var timeObserver: Any?
    private var controlStatus: ControlStatus = .initialize
    private let resourceLoader: AssetResourceLoader
    private var playStatus: PlayStatus = .initialize {
        didSet {
            delegate?.videoPlayerPlayStatusChanged(player: self, status: playStatus)
            print("-------player status: \(playStatus)")
        }
    }
    private var currentTime: TimeInterval = 0 {
        didSet {
            delegate?.videoPlayerPlayDuration(player: self, duration: duration, currentTime: currentTime)
        }
    }
    private var duration: TimeInterval = 0 {
        didSet {
            delegate?.videoPlayerPlayDuration(player: self, duration: duration, currentTime: currentTime)
        }
    }
    private var loadedTime: TimeInterval = 0 {
        didSet {
            delegate?.videoPlayerLoadedTime(player: self, time: loadedTime)
        }
    }
    private var observationList: [NSKeyValueObservation] = []
    weak var delegate: VideoPlayerDelegate?
    
    init(url: URL, delegate: VideoPlayerDelegate?) {
        self.delegate = delegate
        self.url = url
//        let loader = SimpleResourceLoaderDelegate(withURL: url)
//        urlAsset = AVURLAsset(url: loader.streamingAssetURL)
//        loader.completion = { localFileURL in
//            if let localFileURL = localFileURL {
//                print("Media file saved to: \(localFileURL)")
//            } else {
//                print("Failed to download media file.")
//            }
//        }
//        resourceLoader = loader
        
        let loader = AssetResourceLoader(url: url)
        urlAsset = AVURLAsset(url: loader.playerUrl ?? url)
        resourceLoader = loader
        
        urlAsset.resourceLoader.setDelegate(loader, queue: .main)
        playerItem = AVPlayerItem(asset: urlAsset, automaticallyLoadedAssetKeys: ["duration"])
        
        player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = false
        player.replaceCurrentItem(with: playerItem)
        
        videoView = VideoRenderView(frame: .zero, player: player)
        super.init()
        addPlayerItemObservers()
        addPeriodicTimeObserver()
    }
    
    deinit {
        removePlayerItemObservers()
        removePeriodicTimeObserver()
        videoView.removeFromSuperview()
        player.pause()
        player.cancelPendingPrerolls()
        playerItem.cancelPendingSeeks()
        urlAsset.cancelLoading()
        player.replaceCurrentItem(with: nil)
    }
}

// MARK: - 播放控制
extension VideoPlayer {
    func play(to containerView: UIView) {
        videoView.frame = containerView.bounds
        containerView.addSubview(videoView)
        controlStatus = .play
        if playStatus == .pause || playStatus == .ready {
            internalPlay()
        }
    }
    
    func play() {
        if controlStatus == .end {
            controlStatus = .play
            internalSeekTo(time: 0)
        } else {
            controlStatus = .play
            if playStatus == .pause || playStatus == .ready {
                internalPlay()
            }
        }
    }
    
    func pause() {
        guard controlStatus == .play else {
            return
        }
        controlStatus = .pause
        internalPause()
    }
    
    func seekTo(time: TimeInterval) {
        internalSeekTo(time: time)
    }
}

// MARK: - 内部控制调用
extension VideoPlayer {
    private func internalPlay() {
        guard PlayerUtil.appIsActive else {
            return
        }
        internalForcePlay()
    }
    
    private func internalForcePlay() {
        guard controlStatus == .play else {
            return
        }
        playStatus = .playing
        player.play()
    }
    
    private func internalPause() {
        playStatus = .pause
        player.pause()
    }
    
    private func internalSeekTo(time: TimeInterval) {
        if playStatus == .playing || playStatus == .stalled {
            player.pause()
        }
        playerItem.cancelPendingSeeks()
        playStatus = .seeking
        let seekTime = min(time, duration)
        player.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600), toleranceBefore: CMTime(value: 1, timescale: 1), toleranceAfter: CMTime(value: 1, timescale: 1)) { [weak self] (finished) in
            guard finished else { return }
            self?.internalPlay()
            self?.currentTime = time
        }
    }
}

// MARK: - 播放状态监听
extension VideoPlayer {
    /// 播放状态改变
    private func observedPlayerStatusDidChanged() {
        let status = playerItem.status
        switch status {
        case .unknown:
            failedToPlay()
        case .readyToPlay:
            readyToPlay()
        case .failed:
            failedToPlay()
        }
    }
    
    private func readyToPlay() {
        duration = playerItem.asset.duration.seconds
        /// 当前不是播放状态
        if controlStatus != .play {
            return
        }
        /// 当前app不在活跃状态
        if !PlayerUtil.appIsActive {
            return
        }
        playStatus = .playing
        if let progress = delegate?.videoPlayerRecordProgress(player: self), progress > 0 {
            internalSeekTo(time: progress)
        } else {
            internalPlay()
        }
    }
    
    /// 加载进度改变
    private func observedLoadedTimeRangesChanged(time: TimeInterval) {
        loadedTime = max(loadedTime, time)
        checkTryPlay()
    }
    
    private func checkTryPlay() {
        guard PlayerUtil.appIsActive, controlStatus == .play else {
            return
        }
        /// 缓冲进度基本完成
        if playerItem.duration.seconds > 0, playerItem.duration.seconds < loadedTime + 0.5 {
            if playStatus == .initialize {
                playStatus = .ready
            }
            internalPlay()
        }
        /// 当前可用缓冲进度超过6s开始播放
        else if loadedTime > playerItem.currentTime().seconds + 6 {
            if playStatus == .initialize {
                playStatus = .ready
            }
            internalPlay()
        }
    }
    
    /// 是否可播状态改变
    private func observedPlaybackLikelyToKeepUpChanged() {
        checkTryPlay()
    }
    
    /// 中断
    private func playerChangedStalled() {
        guard playStatus == .playing else {
            return
        }
        if (!playerItem.isPlaybackLikelyToKeepUp) && (CMTimeCompare(playerItem.currentTime(), kCMTimeZero) == 1) && (CMTimeCompare(playerItem.currentTime(), playerItem.duration) != 0) {
            playStatus = .stalled
            player.pause()
        }
    }
    /// 播放失败
    private func failedToPlay() {
        player.pause()
        playStatus = .failed
        controlStatus = .failed
    }
}

// MARK: - 通知监控
extension VideoPlayer {
    private func addPlayerItemObservers() {
        let statusObserve = playerItem.observe(\.status) { [weak self] (_, change) in
            self?.observedPlayerStatusDidChanged()
        }
        observationList.append(statusObserve)
        
        let loadObserve = playerItem.observe(\.loadedTimeRanges) { [weak self] _, change in
            guard let v = change.newValue?.first?.timeRangeValue else { return }
            self?.observedLoadedTimeRangesChanged(time: v.end.seconds)
        }
        observationList.append(loadObserve)
        
        let keepUpObserve = playerItem.observe(\.isPlaybackLikelyToKeepUp) { [weak self] _, change in
            self?.observedPlaybackLikelyToKeepUpChanged()
        }
        observationList.append(keepUpObserve)
        
        let durationOberve = playerItem.observe(\.duration) { [weak self] _, chang in
            if let d = chang.newValue?.seconds {
                self?.duration = d
            }
        }
        observationList.append(durationOberve)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledNotification), name: .AVPlayerItemPlaybackStalled, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(failedToPlayToEndTimeNotification), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(didPlayToEndTimeNofitication), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackgroundAction), name: UIScene.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterForegroundAction), name: UIScene.willEnterForegroundNotification, object: nil)
    }
    
    private func removePlayerItemObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 卡顿
    @objc private func playbackStalledNotification() {
        PlayerUtil.doInMainThread { [weak self] in
            self?.playerChangedStalled()
        }
    }
    
    /// 播放失败
    @objc private func failedToPlayToEndTimeNotification() {
        PlayerUtil.doInMainThread { [weak self] in
            self?.failedToPlay()
        }
    }
    /// 播放完成
    @objc private func didPlayToEndTimeNofitication() {
        playStatus = .end
        controlStatus = .end
    }
    
    /// 进入后台
    @objc private func appDidEnterBackgroundAction() {
        internalPause()
    }
    
    /// 进入前台
    @objc private func appDidEnterForegroundAction() {
        internalForcePlay()
    }
}

// MARK: - 时间监控
extension VideoPlayer {
    private func addPeriodicTimeObserver() {
        /// 0.5s回调一次播放时间
        let interval = CMTime(value: 1, timescale: 2)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: .main) { [weak self] (time) in
            guard let self else { return }
            self.currentTime = time.seconds
            if self.controlStatus != .play {
                self.internalPause()
            }
        }
    }

    /// 移除播放时间监听
    private func removePeriodicTimeObserver() {
        guard let timeObserver else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
}


