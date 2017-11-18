//
//  PlayerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

class PlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    let coverArtView = CachedImageView()
    
    let bitRateLabel = UILabel()
    let formatLabel = UILabel()
    
    let titleLabel = UILabel()
    let albumLabel = UILabel()
    let artistLabel = UILabel()
    
    let playButton = UIButton(type: .custom)
    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    let prevButton = UIButton(type: .custom)
    let nextButton = UIButton(type: .custom)
    
    let elapsedLabel = UILabel()
    let remainingLabel = UILabel()
    let progressSlider = UISlider()
    var progressDisplayLink: CADisplayLink!
    
    private var previousBitrates = [Int]()
    let maxPreviousBitrates = 60
    
    var isZoomed = SavedSettings.si.isPlayerZoomed
    var allViews: [UIView] {
        return [coverArtView,
                bitRateLabel, formatLabel,
                titleLabel, albumLabel, artistLabel,
                playButton, spinner, prevButton, nextButton,
                elapsedLabel, remainingLabel, progressSlider]
    }
    var hiddenViews: [UIView] {
        return [bitRateLabel, formatLabel, albumLabel]
    }
    
    let tapRecognizer = UITapGestureRecognizer()
    
    var coverArtViewSize: CGFloat {
        return UIDevice.current.orientation.isLandscape ? 150 : 320
    }
    
    var coverArtViewTopOffset: CGFloat {
        let height = (UIDevice.current.orientation.isLandscape ? portraitScreenSize.width : portraitScreenSize.height)
        return height * 0.1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
        
        coverArtView.isUserInteractionEnabled = true
        self.view.addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.width.equalTo(coverArtViewSize)
            make.height.equalTo(coverArtViewSize)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(coverArtViewTopOffset)
        }
        
        bitRateLabel.textColor = .black
        bitRateLabel.font = .systemFont(ofSize: 13)
        bitRateLabel.textAlignment = .left
        self.view.insertSubview(bitRateLabel, belowSubview: coverArtView)
        bitRateLabel.snp.makeConstraints { make in
            make.top.equalTo(coverArtView.snp.bottom).offset(5)
            make.left.equalTo(coverArtView)
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(15)
        }
        
        formatLabel.textColor = .black
        formatLabel.font = .systemFont(ofSize: 13)
        formatLabel.textAlignment = .right
        self.view.insertSubview(formatLabel, belowSubview: coverArtView)
        formatLabel.snp.makeConstraints { make in
            make.top.equalTo(coverArtView.snp.bottom).offset(5)
            make.right.equalTo(coverArtView)
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(15)
        }
        
        progressSlider.minimumValue = 0.0
        progressSlider.maximumValue = 1.0
        progressSlider.isContinuous = false
        progressSlider.addTarget(self, action: #selector(progressSliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(progressSliderTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        self.view.addSubview(progressSlider)
        progressSlider.snp.makeConstraints { make in
            make.width.equalTo(280)
            make.height.equalTo(30)
            make.centerX.equalTo(coverArtView)
            make.top.equalTo(coverArtView.snp.bottom).offset(40)
        }
        
        elapsedLabel.textColor = .black
        elapsedLabel.font = .systemFont(ofSize: 13)
        elapsedLabel.textAlignment = .right
        self.view.addSubview(elapsedLabel)
        elapsedLabel.snp.makeConstraints { make in
            make.centerY.equalTo(progressSlider)
            make.right.equalTo(progressSlider.snp.left).offset(-5)
            make.width.equalTo(50)
            make.height.equalTo(30)
        }
        
        remainingLabel.textColor = .black
        remainingLabel.font = .systemFont(ofSize: 13)
        remainingLabel.textAlignment = .left
        self.view.addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints { make in
            make.centerY.equalTo(progressSlider)
            make.left.equalTo(progressSlider.snp.right).offset(5)
            make.width.equalTo(50)
            make.height.equalTo(20)
        }
        
        progressDisplayLink = CADisplayLink(target: self, selector: #selector(updateProgress))
        progressDisplayLink.isPaused = true
        progressDisplayLink.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        
        titleLabel.textColor = .black
        titleLabel.font = .systemFont(ofSize: 19)
        titleLabel.textAlignment = .center
        self.view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(progressSlider.snp.bottom).offset(20)
            make.width.equalTo(300)
            make.height.equalTo(25)
        }
        
        albumLabel.textColor = .darkGray
        albumLabel.font = .systemFont(ofSize: 16)
        albumLabel.textAlignment = .center
        self.view.addSubview(albumLabel)
        albumLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.width.equalTo(300)
            make.height.equalTo(25)
        }
        
        artistLabel.textColor = .black
        artistLabel.font = .systemFont(ofSize: 19)
        artistLabel.textAlignment = .center
        self.view.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(albumLabel.snp.bottom).offset(5)
            make.width.equalTo(300)
            make.height.equalTo(25)
        }
        
        playButton.setTitleColor(.black, for: UIControlState())
        playButton.titleLabel?.font = .systemFont(ofSize: 35)
        playButton.addTarget(self, action: #selector(playPause), for: .touchUpInside)
        self.view.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
            make.centerX.equalToSuperview()
            make.top.equalTo(artistLabel.snp.bottom).offset(20)
        }
        
        spinner.hidesWhenStopped = true
        self.view.addSubview(spinner)
        spinner.snp.makeConstraints { make in
            make.centerX.equalTo(playButton)
            make.centerY.equalTo(playButton)
        }
        
        prevButton.setTitleColor(.black, for: UIControlState())
        prevButton.titleLabel?.font = .systemFont(ofSize: 35)
        prevButton.setTitle("«", for: UIControlState())
        prevButton.addTarget(self, action: #selector(previousSong), for: .touchUpInside)
        self.view.addSubview(prevButton)
        prevButton.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
            make.right.equalTo(playButton.snp.left).offset(-20)
            make.centerY.equalTo(playButton).offset(-2)
        }
        
        nextButton.setTitleColor(.black, for: UIControlState())
        nextButton.titleLabel?.font = .systemFont(ofSize: 35)
        nextButton.setTitle("»", for: UIControlState())
        nextButton.addTarget(self, action: #selector(nextSong), for: .touchUpInside)
        self.view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
            make.left.equalTo(playButton.snp.right).offset(20)
            make.centerY.equalTo(playButton).offset(-2)
        }
        
        updatePlayButton()
        updateCurrentSong()
        updateProgress()
        
        if GaplessPlayer.si.isPlaying {
            playbackStarted()
        }
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackStarted), name: GaplessPlayer.Notifications.songStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackPaused), name: GaplessPlayer.Notifications.songPaused)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playbackEnded), name: GaplessPlayer.Notifications.songEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(indexChanged), name: PlayQueue.Notifications.indexChanged)
        
        tapRecognizer.addTarget(self, action: #selector(toggleZoom))
        coverArtView.addGestureRecognizer(tapRecognizer)
        
//        if isZoomed {
//            zoom(animated: false)
//        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coverArtView.snp.updateConstraints { make in
            make.height.equalTo(coverArtViewSize)
            make.width.equalTo(coverArtViewSize)
            make.top.equalToSuperview().offset(coverArtViewTopOffset)
        }
        
        coordinator.animate(alongsideTransition: { context in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self, name: GaplessPlayer.Notifications.songStarted)
        NotificationCenter.removeObserverOnMainThread(self, name: GaplessPlayer.Notifications.songPaused)
        NotificationCenter.removeObserverOnMainThread(self, name: GaplessPlayer.Notifications.songEnded)
        NotificationCenter.removeObserverOnMainThread(self, name: PlayQueue.Notifications.indexChanged)
    }
    
    @objc fileprivate func playPause() {
        if !GaplessPlayer.si.isStarted {
            spinner.startAnimating()
        }
        
        PlayQueue.si.playPause()
    }
    
    @objc fileprivate func previousSong() {
        PlayQueue.si.playPreviousSong()
    }
    
    @objc fileprivate func nextSong() {
        PlayQueue.si.playNextSong()
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
    
    fileprivate func updatePlayButton(_ playing: Bool = GaplessPlayer.si.isPlaying) {
        if playing {
            playButton.setTitle("Ⅱ", for: UIControlState())
        } else {
            playButton.setTitle("▶", for: UIControlState())
        }
    }
    
    fileprivate func updateCurrentSong() {
        let currentSong = PlayQueue.si.currentDisplaySong
        if let coverArtId = currentSong?.coverArtId, let serverId = currentSong?.serverId {
            coverArtView.loadImage(coverArtId: coverArtId, serverId: serverId, size: .player)
        } else {
            coverArtView.setDefaultImage(forSize: .player)
        }
        
        previousBitrates = [Int]()
        bitRateLabel.text = ""
        formatLabel.text = currentSong?.currentContentType?.fileExtension.uppercased()
        
        titleLabel.text = currentSong?.title
        albumLabel.text = currentSong?.albumDisplayName
        artistLabel.text = currentSong?.artistDisplayName
    }
    
    @objc fileprivate func updateProgress() {
        let progress = GaplessPlayer.si.progress
        let progressPercent = GaplessPlayer.si.progressPercent
        
        progressSlider.value = Float(progressPercent)
        elapsedLabel.text = NSString.formatTime(progress)
        if let duration = PlayQueue.si.currentDisplaySong?.duration, let formattedTime = NSString.formatTime(Double(duration) - progress) {
            remainingLabel.text = "-\(formattedTime)"
        }
        
        if previousBitrates.count > maxPreviousBitrates {
            previousBitrates.removeFirst()
        }
        previousBitrates.append(GaplessPlayer.si.bitRate)
        let averageBitrate = previousBitrates.reduce(0, +) / previousBitrates.count
        
        if progress > 5.0 {
            bitRateLabel.text = "\(averageBitrate) kbps"
        }
    }
    
    @objc fileprivate func progressSliderTouchDown() {
        progressDisplayLink.isPaused = true
    }
    
    @objc fileprivate func progressSliderTouchUp() {
        progressDisplayLink.isPaused = false
    }
    
    @objc fileprivate func progressSliderValueChanged() {
        GaplessPlayer.si.seek(percent: Double(progressSlider.value), fadeDuration: 0.5)
    }
    
    fileprivate func zoom(animated: Bool = true) {
        if isZoomed {
            func animations() {
                for view in self.hiddenViews {
                    view.alpha = 0.0
                    view.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
                }
                
                // Constants
                
                //let viewHeight = self.view.frame.height
                let coverWidth = self.coverArtView.frame.width
                let coverScalePercent = self.view.frame.width / coverWidth
                let labelScalePercent: CGFloat = 1.5
                let buttonScalePercent: CGFloat = 2.0
                let sliderTranslateY: CGFloat = 30
                
                // Cover
                
                let coverScaledFrame = self.coverArtView.scaledFrame(x: coverScalePercent, y: coverScalePercent)
                var coverTransform = CGAffineTransform.identity.scaledBy(x: coverScalePercent, y: coverScalePercent)
                coverTransform = coverTransform.translatedBy(x: 0, y: 20 - coverScaledFrame.minY)
                self.coverArtView.transform = coverTransform
                self.coverArtView.contentScaleFactor *= coverScalePercent
                
                // Slider
                
                self.elapsedLabel.transform = CGAffineTransform.identity.translatedBy(x: 0, y: sliderTranslateY)
                self.progressSlider.transform = CGAffineTransform.identity.translatedBy(x: 0, y: sliderTranslateY)
                self.remainingLabel.transform = CGAffineTransform.identity.translatedBy(x: 0, y: sliderTranslateY)
                
                // Labels
                
                var titleTransform = CGAffineTransform.identity.scaledBy(x: labelScalePercent, y: labelScalePercent)
                titleTransform = titleTransform.translatedBy(x: 0, y: 25)
                self.titleLabel.transform = titleTransform
                self.titleLabel.contentScaleFactor *= labelScalePercent
                
                var artistTransform = CGAffineTransform.identity.scaledBy(x: labelScalePercent, y: labelScalePercent)
                artistTransform = artistTransform.translatedBy(x: 0, y: 15)
                self.artistLabel.transform = artistTransform
                self.artistLabel.contentScaleFactor *= labelScalePercent
                
                // Buttons
                
                //let prevScaledFrame = self.prevButton.scaledFrame(x: buttonScalePercent, y: buttonScalePercent)
                var prevTransform = CGAffineTransform.identity.scaledBy(x: buttonScalePercent, y: buttonScalePercent)
                prevTransform = prevTransform.translatedBy(x: -40, y: 20)//(viewHeight - prevScaledFrame.maxY) / 2)
                self.prevButton.transform = prevTransform
                self.prevButton.titleLabel?.contentScaleFactor *= buttonScalePercent
                
                var playTransform = CGAffineTransform.identity.scaledBy(x: buttonScalePercent, y: buttonScalePercent)
                playTransform = playTransform.translatedBy(x: 0, y: 20)
                self.playButton.transform = playTransform
                self.playButton.titleLabel?.contentScaleFactor *= buttonScalePercent
                
                var nextTransform = CGAffineTransform.identity.scaledBy(x: buttonScalePercent, y: buttonScalePercent)
                nextTransform = nextTransform.translatedBy(x: 40, y: 20)
                self.nextButton.transform = nextTransform
                self.nextButton.titleLabel?.contentScaleFactor *= buttonScalePercent
            }
            
            if animated {
                UIView.animate(withDuration: 0.3, animations: animations)
            } else {
                animations()
            }
        } else {
            func animations() {
                for hiddenView in self.hiddenViews {
                    hiddenView.alpha = 1.0
                }
                for view in self.allViews {
                    view.transform = .identity
                }
            }
            
            func completion(finished: Bool) {
                let screenScale = UIScreen.main.scale
                for view in self.allViews {
                    if let button = view as? UIButton {
                        button.titleLabel?.contentScaleFactor = screenScale
                    } else {
                        view.contentScaleFactor = screenScale
                    }
                }
            }
            
            if animated {
                UIView.animate(withDuration: 0.3, animations: animations, completion: completion)
            } else {
                animations()
                completion(finished: true)
            }
        }
    }
    
    @objc fileprivate func toggleZoom() {
        isZoomed = !isZoomed
        SavedSettings.si.isPlayerZoomed = isZoomed
        zoom()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
