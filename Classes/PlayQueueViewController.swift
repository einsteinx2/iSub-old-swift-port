//
//  PlayQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

class PlayQueueViewController: UIViewController {

    let nowPlayingView = UIView()
    let nowPlayingArtView = AsynchronousImageView()
    let nowPlayingSongLabel = UILabel()
    let nowPlayingArtistLabel = UILabel()
    let tableView = UITableView()
    
    private let viewModel: PlayQueueViewModel
    private let reuseIdentifier = "Item Cell"
    
    init(viewModel: PlayQueueViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        self.viewModel.delegate = self
        
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewController.draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewController.draggingMoved(_:)), name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewController.draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueueViewController.draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    deinit {
        NSNotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    ///////////
    
    func clearPlayQueue() {
        PlayQueue.sharedInstance.reset()
    }
    
    ///////////

    override func loadView() {
        self.view = UIView()
        self.view.backgroundColor = UIColor.blackColor()
        
        nowPlayingView.backgroundColor = UIColor.lightGrayColor()
        self.view.addSubview(nowPlayingView)
        nowPlayingView.snp_makeConstraints { make in
            make.top.equalTo(self.view).offset(20)
            make.leading.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.height.equalTo(60)
        }
        
        let button = UIButton()
        button.addTarget(self, action: #selector(PlayQueueViewController.clearPlayQueue), forControlEvents: .TouchUpInside)
        self.view.addSubview(button)
        button.snp_makeConstraints { make in
            make.top.equalTo(nowPlayingView)
            make.leading.equalTo(nowPlayingView)
            make.trailing.equalTo(nowPlayingView)
            make.height.equalTo(nowPlayingView)
        }
        
        nowPlayingView.addSubview(nowPlayingArtView)
        nowPlayingArtView.snp_makeConstraints { make in
            make.top.equalTo(nowPlayingView)
            make.leading.equalTo(nowPlayingView)
            make.bottom.equalTo(nowPlayingView)
            make.width.equalTo(60)
        }
        
        nowPlayingSongLabel.font = UIFont.systemFontOfSize(14)
        nowPlayingSongLabel.textColor = UIColor.blackColor()
        nowPlayingSongLabel.textAlignment = .Center
        nowPlayingView.addSubview(nowPlayingSongLabel)
        nowPlayingSongLabel.snp_makeConstraints { make in
            make.top.equalTo(nowPlayingView)
            make.leading.equalTo(nowPlayingArtView.snp_trailing).offset(5)
            make.trailing.equalTo(nowPlayingView).inset(5)
            make.height.equalTo(40)
        }
        
        nowPlayingArtistLabel.font = UIFont.systemFontOfSize(10)
        nowPlayingArtistLabel.textColor = UIColor.grayColor()
        nowPlayingArtistLabel.textAlignment = .Center
        nowPlayingView.addSubview(nowPlayingArtistLabel)
        nowPlayingArtistLabel.snp_makeConstraints { make in
            make.top.equalTo(nowPlayingSongLabel.snp_bottom)
            make.leading.equalTo(nowPlayingSongLabel)
            make.trailing.equalTo(nowPlayingSongLabel)
            make.height.equalTo(20)
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.clearColor()
        tableView.separatorColor = UIColor.clearColor()
        tableView.registerClass(NewItemTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        self.view.addSubview(tableView)
        tableView.snp_makeConstraints { make in
            make.top.equalTo(nowPlayingView.snp_bottom)
            make.leading.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.bottom.equalTo(self.view)
        }
        
        updateNowPlayingView()
    }
    
    func updateNowPlayingView() {
        if let song = viewModel.currentSong {
            nowPlayingArtView.coverArtId = song.coverArtId?.stringValue
            nowPlayingSongLabel.text = song.title
            nowPlayingArtistLabel.text = song.artist?.name
        } else {
            nowPlayingArtView.coverArtId = nil
            nowPlayingSongLabel.text = ""
            nowPlayingArtistLabel.text = ""
        }
    }
    
    // MARK - Drag and Drop -
    
    @objc private func draggingBegan(notification: NSNotification) {
        
    }
    
    @objc private func draggingMoved(notification: NSNotification) {
        
    }
    
    @objc private func draggingEnded(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let song = userInfo[DraggableTableView.Notifications.itemKey] as? ISMSSong, location = userInfo[DraggableTableView.Notifications.locationKey] as? NSValue {
                let point = location.CGPointValue()
                let localPoint = self.view.convertPoint(point, fromView: nil)
                print("point: \(point)  localPoint: \(localPoint)  self.view.bounds: \(self.view.bounds)  containsPoint: \(self.view.bounds.contains(localPoint))")
                if self.view.bounds.contains(localPoint) {
                    Playlist.playQueue.addSong(song: song)
                }
            }
        }
    }
    
    @objc private func draggingCanceled(notification: NSNotification) {
        
    }
}

extension PlayQueueViewController: PlayQueueViewModelDelegate {
    func itemsChanged() {
        updateNowPlayingView()
        self.tableView.reloadData()
    }
}
    
extension PlayQueueViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfTableViewRows
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! NewItemTableViewCell
        cell.alwaysShowSubtitle = true
        cell.accessoryType = UITableViewCellAccessoryType.None
        
        let song = viewModel.songForTableViewIndex(indexPath.row)
        cell.indexPath = indexPath
        cell.associatedObject = song
        cell.coverArtId = nil
        cell.trackNumber = song.trackNumber
        cell.title = song.title
        cell.subTitle = song.artist?.name
        cell.duration = song.duration
        // TODO: Readd this with new data model
        //cell.playing = song.isCurrentPlayingSong()
        
        if song.isFullyCached {
            cell.backgroundView = UIView()
            cell.backgroundView!.backgroundColor = ViewObjectsSingleton.sharedInstance().currentLightColor()
        } else {
            cell.backgroundView = UIView()
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return ISMSNormalize(ISMSSongCellHeight)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        viewModel.playSongAtTableViewIndex(indexPath.row)
    }
}