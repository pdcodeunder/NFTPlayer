//
//  ViewController.swift
//  NFTPlayer
//
//  Created by pengdong on 08/25/2023.
//  Copyright (c) 2023 pengdong. All rights reserved.
//

import UIKit
import NFTPlayer

class ViewController: UIViewController {
    class SourceItem: MediaConvertible {
        func urls() -> [URL] {
            videoUrls
        }
        
        let title: String
        let videoUrls: [URL]
        
        init(title: String, videoUrls: [URL]) {
            self.title = title
            self.videoUrls = videoUrls
        }
    }
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var dataSource: [SourceItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        title = "NFTPlayer"
        createDataSource()
        
        tableView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)
        tableView.separatorStyle = .none
        tableView.register(ItemCell.self, forCellReuseIdentifier: "ItemCell")
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func createDataSource() {
        dataSource = [
            SourceItem(title: "标题1", videoUrls: [URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!]),
            SourceItem(title: "标题2", videoUrls: [URL(string: "http://www.w3school.com.cn/example/html5/mov_bbb.mp4")!]),
            SourceItem(title: "标题3", videoUrls: [URL(string: "https://www.w3schools.com/html/movie.mp4")!]),
            SourceItem(title: "标题4", videoUrls: [URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!]),
            SourceItem(title: "标题6", videoUrls: [URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!]),
            SourceItem(title: "标题7", videoUrls: [URL(string: "http://www.w3school.com.cn/example/html5/mov_bbb.mp4")!]),
            SourceItem(title: "标题8", videoUrls: [URL(string: "https://www.w3schools.com/html/movie.mp4")!]),
            SourceItem(title: "标题9", videoUrls: [URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!]),
            SourceItem(title: "标题10", videoUrls: [URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!]),
            SourceItem(title: "标题12", videoUrls: [URL(string: "https://www.w3schools.com/html/movie.mp4")!]),
            SourceItem(title: "标题13", videoUrls: [URL(string: "http://www.w3school.com.cn/example/html5/mov_bbb.mp4")!]),
            SourceItem(title: "标题14", videoUrls: [URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!])
        ]
        PlayerPreDownloader.preload(urls: [
            URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
            URL(string: "http://www.w3school.com.cn/example/html5/mov_bbb.mp4")!,
            URL(string: "https://www.w3schools.com/html/movie.mp4")!,
            URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!,
        ], length: 30 * 1024)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath) as? ItemCell else {
            return UITableViewCell()
        }
        if dataSource.count > indexPath.row {
            let item = dataSource[indexPath.row]
            cell.bindItem(item)
            cell.playClickAction = { [weak self] (container) in
                self?.playVideoWith(item: item, containerView: container)
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if dataSource.count > indexPath.row {
            let item = dataSource[indexPath.row]
            if let media = PlayerManager.shared.currentMedia as? SourceItem, media === item {
                PlayerManager.shared.stop()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    private func playVideoWith(item: SourceItem, containerView: UIView) {
        PlayerManager.shared.play(media: item, to: containerView, delegate: nil)
    }
}

extension ViewController {
    class ItemCell: UITableViewCell {
        private let nameLabel = UILabel()
        private let videoContainerView = UIView()
        private let playBtn = UIButton()
        var playClickAction: ((UIView) -> Void)?
        
        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            nameLabel.textColor = .black
            nameLabel.font = .systemFont(ofSize: 16)
            contentView.addSubview(nameLabel)
            
            videoContainerView.backgroundColor = .gray
            contentView.addSubview(videoContainerView)
            
            playBtn.setImage(UIImage(named: "play_icon"), for: .normal)
            playBtn.addTarget(self, action: #selector(playBtnClicked), for: .touchUpInside)
            videoContainerView.addSubview(playBtn)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            nameLabel.frame = CGRect(x: 14, y: 10, width: bounds.width - 28, height: 20)
            videoContainerView.frame = CGRect(x: 14, y: nameLabel.frame.maxY + 10, width: bounds.width - 28, height: bounds.height - nameLabel.frame.maxY - 10)
            playBtn.frame = CGRect(x: (videoContainerView.bounds.width - 50) / 2.0, y: (videoContainerView.bounds.height - 50) / 2.0, width: 50, height: 50)
        }
        
        func bindItem(_ item: SourceItem) {
            nameLabel.text = item.title
        }
        
        @objc
        private func playBtnClicked() {
            playClickAction?(videoContainerView)
        }
    }
}
