//
//  MiniPlayerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 6/18/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import libSub

class MiniPlayerViewController: UIViewController {
    let coverArtView = AsynchronousImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    let playButton = UIButton(type: .Custom)
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGrayColor()
        
        self.view.addSubview(coverArtView)
        coverArtView.snp_makeConstraints { make in
            make.left.equalTo(self.view)
            make.top.equalTo(self.view)
            make.bottom.equalTo(self.view)
            make.width.equalTo(coverArtView.snp_height)
        }
        
        playButton.setTitleColor(.blackColor(), forState: .Normal)
        playButton.titleLabel?.font = .systemFontOfSize(20)
        playButton.addTarget(self, action: #selector(MiniPlayerViewController.playPause), forControlEvents: .TouchUpInside)
        self.view.addSubview(playButton)
        playButton.snp_makeConstraints { make in
            make.right.equalTo(self.view)
            make.top.equalTo(self.view)
            make.bottom.equalTo(self.view)
            make.width.equalTo(playButton.snp_height)
        }
        
        spinner.hidesWhenStopped = true
        self.view.addSubview(spinner)
        spinner.snp_makeConstraints { make in
            make.centerX.equalTo(playButton)
            make.centerY.equalTo(playButton)
        }
        
        titleLabel.textColor = .blackColor()
        titleLabel.font = .systemFontOfSize(14)
        self.view.addSubview(titleLabel)
        titleLabel.snp_makeConstraints { make in
            make.left.equalTo(coverArtView.snp_right).offset(5)
            make.right.equalTo(playButton.snp_left).offset(5)
            make.top.equalTo(self.view).offset(5)
            make.height.equalTo(self.view).dividedBy(2)
        }
        
        artistLabel.textColor = .darkGrayColor()
        artistLabel.font = .systemFontOfSize(12)
        self.view.addSubview(artistLabel)
        artistLabel.snp_makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp_bottom)
            make.bottom.equalTo(self.view).offset(-5)
        }
        
        updatePlayButton()
        updateCurrentSong()
        
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(MiniPlayerViewController.playbackStarted), name: ISMSNotification_SongPlaybackStarted, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(MiniPlayerViewController.updatePlayButton), name: ISMSNotification_SongPlaybackPaused, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(MiniPlayerViewController.updatePlayButton), name: ISMSNotification_SongPlaybackEnded, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(MiniPlayerViewController.updateCurrentSong), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    deinit {
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_SongPlaybackStarted, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_SongPlaybackPaused, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_SongPlaybackEnded, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    @objc private func playbackStarted() {
        spinner.stopAnimating()
        updatePlayButton()
    }
    
    @objc private func updatePlayButton(playing: Bool = AudioEngine.sharedInstance().isPlaying()) {
        if playing {
            playButton.setTitle("| |", forState: .Normal)
        } else {
            playButton.setTitle(">", forState: .Normal)
        }
    }
    
    @objc private func updateCurrentSong() {
        let currentSong = PlayQueue.sharedInstance.currentDisplaySong
        coverArtView.coverArtId = currentSong?.coverArtId
        titleLabel.text = currentSong?.title
        artistLabel.text = currentSong?.artistDisplayName
    }
    
    @objc private func playPause() {
        if !AudioEngine.sharedInstance().isStarted() {
            spinner.startAnimating()
        }
        
        PlayQueue.sharedInstance.playPause()
    }
}