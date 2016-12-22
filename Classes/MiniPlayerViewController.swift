//
//  MiniPlayerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 6/18/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class MiniPlayerViewController: UIViewController {
    let coverArtView = AsynchronousImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    let playButton = UIButton(type: .custom)
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
        
        self.view.addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.left.equalTo(self.view)
            make.top.equalTo(self.view)
            make.bottom.equalTo(self.view)
            make.width.equalTo(coverArtView.snp.height)
        }
        
        playButton.setTitleColor(.black, for: UIControlState())
        playButton.titleLabel?.font = .systemFont(ofSize: 20)
        playButton.addTarget(self, action: #selector(MiniPlayerViewController.playPause), for: .touchUpInside)
        self.view.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.right.equalTo(self.view)
            make.top.equalTo(self.view)
            make.bottom.equalTo(self.view)
            make.width.equalTo(playButton.snp.height)
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
            make.top.equalTo(self.view).offset(5)
            make.height.equalTo(self.view).dividedBy(2)
        }
        
        artistLabel.textColor = .darkGray
        artistLabel.font = .systemFont(ofSize: 12)
        self.view.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalTo(self.view).offset(-5)
        }
        
        updatePlayButton()
        updateCurrentSong()
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(MiniPlayerViewController.playbackStarted), name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(MiniPlayerViewController.updatePlayButton), name: ISMSNotification_SongPlaybackPaused, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(MiniPlayerViewController.updatePlayButton), name: ISMSNotification_SongPlaybackEnded, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(MiniPlayerViewController.updateCurrentSong), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackPaused, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackEnded, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    @objc fileprivate func playbackStarted() {
        spinner.stopAnimating()
        updatePlayButton()
    }
    
    @objc fileprivate func updatePlayButton(_ playing: Bool = AudioEngine.sharedInstance().isPlaying()) {
        if playing {
            playButton.setTitle("| |", for: UIControlState())
        } else {
            playButton.setTitle(">", for: UIControlState())
        }
    }
    
    @objc fileprivate func updateCurrentSong() {
        let currentSong = PlayQueue.sharedInstance.currentDisplaySong
        coverArtView.coverArtId = currentSong?.coverArtId
        titleLabel.text = currentSong?.title
        artistLabel.text = currentSong?.artistDisplayName
    }
    
    @objc fileprivate func playPause() {
        if !AudioEngine.sharedInstance().isStarted() {
            spinner.startAnimating()
        }
        
        PlayQueue.sharedInstance.playPause()
    }
}
