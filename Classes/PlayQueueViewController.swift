//
//  PlayQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class PlayQueueViewController: CustomUITableViewController {

    private let viewModel: PlayQueueViewModel
    private let reuseIdentifier = "Item Cell"
    
    init(viewModel: PlayQueueViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "PlayQueueViewController", bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(NewItemUITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.darkGrayColor()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table View Delegate -
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.songs.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! NewItemUITableViewCell
        cell.alwaysShowSubtitle = true
        //cell.delegate = self
        
        cell.accessoryType = UITableViewCellAccessoryType.None
        
        let song = viewModel.songs[indexPath.row]
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
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return ISMSNormalize(ISMSSongCellHeight)
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        PlayQueue.sharedInstance.playSongAtIndex(indexPath.row)
    }
}
