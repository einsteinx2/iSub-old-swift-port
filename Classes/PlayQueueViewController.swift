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
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

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
        tableView.registerClass(NewItemUITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
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
        
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! NewItemUITableViewCell
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