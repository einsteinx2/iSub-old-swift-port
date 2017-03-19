//
//  MiniPlayerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 6/18/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class MiniPlayerViewController: UIViewController {
    let coverArtView = CachedImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    let playButton = UIButton(type: .custom)
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    let progressView = UIView()
    var progressDisplayLink: CADisplayLink!
    
    let tapRecognizer = UITapGestureRecognizer()
    let swipeRecognizer = UISwipeGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
        
        self.view.addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(self.view.snp.height)
        }
        
        playButton.setTitleColor(.black, for: UIControlState())
        playButton.titleLabel?.font = .systemFont(ofSize: 20)
        playButton.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        self.view.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(self.view.snp.height)
        }
        
        spinner.hidesWhenStopped = true
        self.view.addSubview(spinner)
        spinner.snp.makeConstraints { make in
            make.centerX.equalTo(playButton)
            make.centerY.equalTo(playButton)
        }
        
        titleLabel.textColor = .black
        titleLabel.font = .systemFont(ofSize: 14)
        self.view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(coverArtView.snp.right).offset(5)
            make.right.equalTo(playButton.snp.left).offset(5)
            make.top.equalToSuperview().offset(5)
            make.height.equalToSuperview().dividedBy(2)
        }
        
        artistLabel.textColor = .darkGray
        artistLabel.font = .systemFont(ofSize: 12)
        self.view.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalToSuperview().offset(-5)
        }
        
        progressView.backgroundColor = .white
        self.view.addSubview(progressView)
        progressView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.width.equalTo(0)
            make.height.equalTo(3)
            make.bottom.equalToSuperview()
        }
        
        progressDisplayLink = CADisplayLink(target: self, selector: #selector(updateProgressView))
        progressDisplayLink.isPaused = true
        progressDisplayLink.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        
        updatePlayButton()
        updateCurrentSong()
        updateProgressView()
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackStarted), name: BassGaplessPlayer.Notifications.songStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackPaused), name: BassGaplessPlayer.Notifications.songPaused)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackEnded), name: BassGaplessPlayer.Notifications.songEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(indexChanged), name: PlayQueue.Notifications.indexChanged)
        
        tapRecognizer.addTarget(self, action: #selector(showPlayer))
        self.view.addGestureRecognizer(tapRecognizer)
        
        swipeRecognizer.direction = .up
        swipeRecognizer.addTarget(self, action: #selector(showPlayer))
        self.view.addGestureRecognizer(swipeRecognizer)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self, name: BassGaplessPlayer.Notifications.songStarted)
        NotificationCenter.removeObserverOnMainThread(self, name: BassGaplessPlayer.Notifications.songPaused)
        NotificationCenter.removeObserverOnMainThread(self, name: BassGaplessPlayer.Notifications.songEnded)
        NotificationCenter.removeObserverOnMainThread(self, name: PlayQueue.Notifications.indexChanged)
    }
    
    @objc fileprivate func playPause() {
        if !BassGaplessPlayer.si.isStarted {
            spinner.startAnimating()
        }
        
        PlayQueue.si.playPause()
    }
    
    @objc fileprivate func playbackStarted() {
        spinner.stopAnimating()
        updatePlayButton()
        progressDisplayLink.isPaused = false
    }
    
    @objc fileprivate func playbackPaused() {
        updatePlayButton()
        progressDisplayLink.isPaused = true
    }
    
    @objc fileprivate func playbackEnded() {
        updatePlayButton()
        progressDisplayLink.isPaused = true
    }
    
    @objc fileprivate func indexChanged() {
        updateCurrentSong()
    }
    
    fileprivate func updatePlayButton(_ playing: Bool = BassGaplessPlayer.si.isPlaying) {
        if playing {
            playButton.setTitle("| |", for: UIControlState())
        } else {
            playButton.setTitle(">", for: UIControlState())
        }
    }
    
    fileprivate func updateCurrentSong() {
        let currentSong = PlayQueue.si.currentDisplaySong
        if let coverArtId = currentSong?.coverArtId, let serverId = currentSong?.serverId {
            coverArtView.loadImage(coverArtId: coverArtId, serverId: serverId, size: .cell)
        } else {
            coverArtView.setDefaultImage(forSize: .cell)
        }
        titleLabel.text = currentSong?.title
        artistLabel.text = currentSong?.artistDisplayName
    }
    
    @objc fileprivate func updateProgressView() {
        let progress = BassGaplessPlayer.si.progressPercent
        let width = self.view.frame.width * CGFloat(progress)
        progressView.snp.updateConstraints { make in
            make.width.equalTo(width)
        }
    }
    
    @objc fileprivate func showPlayer() {
        self.parent?.present(PlayerViewController(), animated: true, completion: nil)
    }
}
