//
//  PlayerInterfaceView.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/28.
//

import Foundation
import UIKit

// MARK: - 视频交互控件协议
public protocol PlayerInterfaceViewProtocol: UIView {
    var isPause: Bool { get set }
    var duration: TimeInterval { get set }
    var loadedTime: TimeInterval { get set }
    var currentTime: TimeInterval { get set }
    var isLoading: Bool { get set }
    
    func clear()
    
    func playerFinish()
}

// MARK: - 默认视频交互控件
class PlayerInterfaceDefaultView: UIView, PlayerInterfaceViewProtocol {
    private let bottomView = UIView()
    private let pauseBtn = UIButton()
    private let bottomGradientLayer = CAGradientLayer()
    private let timeLabel = UILabel()
    private let progressView = UIView()
    private let totalLayer = CALayer()
    private let loadedLayer = CALayer()
    private let timeLayer = CALayer()
    private let timeDot = UIView()
    private let durationLabel = UILabel()
    private let loadingView = UIActivityIndicatorView(style: .medium)
    private var isSeeking = false
    private var timer: Timer?
    var currentTime: TimeInterval = 0 {
        didSet {
            playVideoTimeDidChanged()
        }
    }
    var duration: TimeInterval = 0 {
        didSet {
            playVideoTimeDidChanged()
        }
    }
    var loadedTime: TimeInterval = 0 {
        didSet {
            refreshPlayerTimeUI()
        }
    }
    var isPause: Bool = true {
        didSet {
            if isPause {
                pauseBtn.setImage(UIImage(playerImageName: "player_control_icon_pause"), for: .normal)
                showControlUI(autoHidden: false)
            } else {
                pauseBtn.setImage(UIImage(playerImageName: "player_control_icon_play"), for: .normal)
                showControlUI(autoHidden: true)
            }
        }
    }
    var isLoading: Bool = false {
        didSet {
            guard isLoading != oldValue else { return }
            loadingView.isHidden = !isLoading
            if isLoading {
                loadingView.startAnimating()
            } else {
                loadingView.stopAnimating()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(bottomView)
        
        pauseBtn.setImage(UIImage(playerImageName: "player_control_icon_pause"), for: .normal)
        pauseBtn.addTarget(self, action: #selector(pauseActionHandler), for: .touchUpInside)
        addSubview(pauseBtn)
        
        bottomGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        bottomGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        bottomGradientLayer.colors = [UIColor.black.withAlphaComponent(0.3).cgColor, UIColor.black.withAlphaComponent(0.8).cgColor]
        bottomView.layer.addSublayer(bottomGradientLayer)
        
        timeLabel.font = UIFont.systemFont(ofSize: 14)
        timeLabel.textColor = .white
        bottomView.addSubview(timeLabel)
        
        bottomView.addSubview(progressView)
        
        totalLayer.backgroundColor = UIColor.white.cgColor
        totalLayer.cornerRadius = 1
        progressView.layer.addSublayer(totalLayer)
        
        loadedLayer.backgroundColor = UIColor.gray.cgColor
        loadedLayer.cornerRadius = 1
        progressView.layer.addSublayer(loadedLayer)
        
        timeLayer.backgroundColor = UIColor.blue.cgColor
        timeLayer.cornerRadius = 1
        progressView.layer.addSublayer(timeLayer)
        
        timeDot.backgroundColor = .white
        timeDot.layer.cornerRadius = 4
        timeDot.layer.masksToBounds = true
        progressView.addSubview(timeDot)
        
        durationLabel.font = UIFont.systemFont(ofSize: 14)
        durationLabel.textColor = .white
        bottomView.addSubview(durationLabel)
        
        loadingView.isHidden = !isLoading
        addSubview(loadingView)
        addEventAction()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        loadingView.frame = CGRect(x: (bounds.width - 30) / 2.0, y: (bounds.height - 30) / 2.0, width: 30, height: 30)
        bottomView.frame = CGRect(x: 0, y: bounds.height - 50, width: bounds.width, height: 50)
        bottomGradientLayer.frame = bottomView.bounds
        pauseBtn.frame = CGRect(x: (bounds.width - 50) / 2.0, y: (bounds.height - 50) / 2.0, width: 50, height: 50)
        timeLabel.frame = CGRect(x: 16, y: (bottomView.bounds.height - 20) / 2.0, width: 60, height: 20)
        durationLabel.frame = CGRect(x: bounds.width - 10 - 60, y: (bottomView.bounds.height - 20) / 2.0, width: 60, height: 20)
        progressView.frame = CGRect(x: timeLabel.frame.maxX, y: (bottomView.frame.height - 30) / 2.0, width: durationLabel.frame.minX - timeLabel.frame.maxX - 10 * 2, height: 30)
        totalLayer.frame = CGRect(x: 0, y: (progressView.frame.height - 2) / 2.0, width: progressView.frame.width, height: 2)
        
        refreshPlayerTimeUI()
    }
    
    private func refreshPlayerTimeUI() {
        var currentTimeCenter: CGFloat = 0
        var loadedCenter: CGFloat = 0
        if duration > 0 {
            currentTimeCenter = totalLayer.frame.width * currentTime / duration
            loadedCenter = totalLayer.frame.width * loadedTime / duration
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        loadedLayer.frame = CGRect(x: 0, y: totalLayer.frame.minY, width: loadedCenter, height: totalLayer.frame.height)
        timeLayer.frame = CGRect(x: 0, y: totalLayer.frame.minY, width: currentTimeCenter, height: totalLayer.frame.height)
        timeDot.frame = CGRect(x: currentTimeCenter - 8, y: timeLayer.frame.minY + (timeLayer.frame.height - 8) / 2.0, width: 8, height: 8)
        CATransaction.commit()
    }
    
    private func playVideoTimeDidChanged() {
        guard !isSeeking else { return }
        refreshPlayerTime()
    }
    
    private func refreshPlayerTime() {
        do {
            let hour = Int(duration / 3600)
            let minute = (Int(duration) % 3600) / 60
            let second = Int(duration) % 60
            durationLabel.text = "\(hour):\(minute):\(second)"
        }
        do {
            let hour = Int(currentTime / 3600)
            let minute = (Int(currentTime) % 3600) / 60
            let second = Int(currentTime) % 60
            timeLabel.text = "\(hour):\(minute):\(second)"
        }
        refreshPlayerTimeUI()
    }
    
    func clear() {
        isPause = true
        isLoading = false
    }
    
    func playerFinish() {
        
    }
    
    private func showControlUI(autoHidden: Bool) {
        bottomView.isHidden = false
        pauseBtn.isHidden = false
        if autoHidden {
            startTime()
        } else {
            stopTime()
        }
    }
    
    private func hiddenControlUI() {
        stopTime()
        bottomView.isHidden = true
        pauseBtn.isHidden = true
    }
    
    private func startTime() {
        timer?.invalidate()
        timer = nil
        let timer = Timer(timeInterval: 5, repeats: false) { [weak self] _ in
            self?.hiddenControlUI()
        }
        RunLoop.current.add(timer, forMode: .common)
        timer.fireDate = Date(timeIntervalSinceNow: 5)
        self.timer = timer
    }
    
    private func stopTime() {
        timer?.invalidate()
        timer = nil
        
    }
}

extension PlayerInterfaceDefaultView {
    private func addEventAction() {
        let mainTap = UITapGestureRecognizer(target: self, action: #selector(selfDidTapAction))
        self.addGestureRecognizer(mainTap)
        
        let bottomTap = UITapGestureRecognizer(target: self, action: #selector(bottomDidTapAction))
        progressView.addGestureRecognizer(bottomTap)
        
        let bottomPan = UIPanGestureRecognizer(target: self, action: #selector(bottomDidPanAction(pan:)))
        progressView.addGestureRecognizer(bottomPan)
    }
    
    @objc private func selfDidTapAction() {
        if bottomView.isHidden {
            showControlUI(autoHidden: true)
        } else {
            hiddenControlUI()
        }
    }
    
    @objc private func bottomDidTapAction(tap: UITapGestureRecognizer) {
        guard duration > 0 else {
            return
        }
        let point = tap.location(in: progressView)
        let time = point.x / progressView.bounds.width * duration
        currentTime = time
        PlayerManager.shared.seek(time: time)
    }
    
    @objc private func bottomDidPanAction(pan: UIPanGestureRecognizer) {
        guard duration > 0 else {
            return
        }
        let point = pan.location(in: progressView)
        let time = point.x / progressView.bounds.width * duration
        currentTime = time
        switch pan.state {
        case .began:
            isSeeking = true
            stopTime()
        case .changed:
            isSeeking = true
        case .cancelled, .ended:
            isSeeking = false
            PlayerManager.shared.seek(time: time)
        default:
            break
        }
        refreshPlayerTime()
    }
    
    @objc private func pauseActionHandler() {
        if isPause {
            PlayerManager.shared.play()
        } else {
            PlayerManager.shared.pause()
        }
    }
}
