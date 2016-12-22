//
//  PlayQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

class PlayQueueViewController: DraggableTableViewController {

    var hoverRow = -1
    
    fileprivate let viewModel: PlayQueueViewModel
    fileprivate let currentItemReuseIdentifier = "Current Item Cell"
    fileprivate let itemReuseIdentifier = "Item Cell"
    fileprivate var internallyDragging = false
    fileprivate var visible: Bool {
        return self.sidePanelController.state == JASidePanelRightVisible
    }
    
    init(viewModel: PlayQueueViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        self.viewModel.delegate = self
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueueViewController.draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueueViewController.draggingMoved(_:)), name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueueViewController.draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(PlayQueueViewController.draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    deinit {
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    // MARK - Drag and Drop -
    
    @objc fileprivate func draggingBegan(_ notification: Notification) {
        if let userInfo = notification.userInfo, let dragSourceTableView = userInfo[DraggableTableView.Notifications.dragSourceTableViewKey] as? UITableView {
            internallyDragging = (dragSourceTableView == self.tableView)
        } else {
            internallyDragging = false
        }
    }
    
    @objc fileprivate func draggingMoved(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let dragCell = userInfo[DraggableTableView.Notifications.dragCellKey] as? DraggableCell, dragCell.dragItem is ISMSSong,
                let location = userInfo[DraggableTableView.Notifications.locationKey] as? NSValue {
                
                var point = location.cgPointValue
                // Treat hovers over the top portion of the cell as the previous cell
                point.y -= (ISMSNormalize(ISMSSongCellHeight) / 2.0)
                let tablePoint = tableView.convert(point, from: nil)
                
                let indexPath = tableView.indexPathForRow(at: tablePoint)
                var row = -1
                if let indexPath = indexPath {
                    row = indexPath.row
                }
                
                if hoverRow != row {
                    hoverRow = row
                    
                    // Reload cell heights
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
        }
    }
    
    @objc fileprivate func draggingEnded(_ notification: Notification) {
        let reloadTable = true
        
        if visible, let userInfo = notification.userInfo {
            if let dragCell = userInfo[DraggableTableView.Notifications.dragCellKey] as? DraggableCell,
                   let song = dragCell.dragItem as? ISMSSong,
                   let location = userInfo[DraggableTableView.Notifications.locationKey] as? NSValue {
                
                let point = location.cgPointValue
                let localPoint = self.view.convert(point, from: nil)
                if self.view.bounds.contains(localPoint) {
                    if internallyDragging, let fromIndex = dragCell.indexPath?.row {
                        if fromIndex != hoverRow {
                            let toIndex = hoverRow + 1
                            if fromIndex != toIndex {
                                viewModel.moveSong(fromIndex: fromIndex, toIndex: toIndex)
                                
                                // TODO: Try and get this to animate well, too many issues right now
//                                reloadTable = false
//
//                                // Close the hover row
//                                let hoverIndexPath = NSIndexPath(forRow: self.hoverRow, inSection: 0)
//                                self.hoverRow = -1
//                                self.tableView.reloadRowsAtIndexPaths([hoverIndexPath], withRowAnimation: .None)
//                                
//                                // Move the rows by first dropping in the new row without animation, 
//                                // then animating out the old row
//                                self.tableView.beginUpdates()
//                                let fromIndexPath = NSIndexPath(forRow: fromIndex, inSection: 0)
//                                let toIndexForInsert = (fromIndex < toIndex) ? toIndex - 1 : toIndex
//                                let toIndexPath = NSIndexPath(forRow: toIndexForInsert, inSection: 0)
////                                self.tableView.insertRowsAtIndexPaths([toIndexPath], withRowAnimation: .None)
////                                self.tableView.deleteRowsAtIndexPaths([fromIndexPath], withRowAnimation: .Left)
//                                self.tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
//                                self.tableView.endUpdates()
//                                
//                                // Reload the original moved row if we're moving down the playlist or it won't update
//                                if fromIndex < toIndex {
//                                    //self.tableView.reloadRowsAtIndexPaths([fromIndexPath], withRowAnimation: .None)
//                                }
                            }
                        }
                    } else if !internallyDragging {
                        viewModel.insertSongAtIndex(hoverRow + 1, song: song)
                    }
                }
            }
        }
        
        if reloadTable {
            self.tableView.reloadData()
        }
        hoverRow = -1
    }
    
    @objc fileprivate func draggingCanceled(_ notification: Notification) {
        self.tableView.reloadData()
        hoverRow = -1
    }
    
    override func customizeTableView(_ tableView: UITableView) {
        // Allow the player to always move to the top
        // TODO: Adjust this so that it never lets you move the player higher than the screen if 
        // there are not more rows
        let appHeight = UIScreen.main.applicationFrame.height
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: appHeight - 60))
        
        tableView.backgroundColor = UIColor.clear
        tableView.separatorColor = UIColor.black
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemReuseIdentifier)
        tableView.register(CurrentItemCell.self, forCellReuseIdentifier: currentItemReuseIdentifier)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        Swift.print("cellForRow \(indexPath.row)  song: \(viewModel.songAtIndex(indexPath.row).title)")
        let row = indexPath.row
        if row == viewModel.currentIndex, let cell = tableView.dequeueReusableCell(withIdentifier: currentItemReuseIdentifier, for: indexPath) as? CurrentItemCell {
            cell.cellHeight = 60.0
            cell.accessoryType = .none
            cell.indexPath = indexPath
            cell.associatedObject = viewModel.songAtIndex(indexPath.row)
            
            return cell
        } else if let cell = tableView.dequeueReusableCell(withIdentifier: itemReuseIdentifier, for: indexPath) as? ItemTableViewCell {
            cell.alwaysShowSubtitle = true
            cell.cellHeight = ISMSNormalize(ISMSSongCellHeight)
            cell.accessoryType = .none
            
            let song = viewModel.songAtIndex(indexPath.row)
            cell.associatedObject = song
            cell.coverArtId = nil
            cell.title = song.title
            cell.subTitle = song.artistDisplayName
            cell.duration = song.duration
            // TODO: Read this with new data model
            //cell.playing = song.isCurrentPlayingSong()
            
            cell.backgroundView = UIView()
            if song.isFullyCached {
                cell.backgroundView!.backgroundColor = ViewObjectsSingleton.sharedInstance().currentLightColor()
            }
            
            return cell
        }
        
        // Should never happen
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height = indexPath.row == viewModel.currentIndex ? 60.0 : ISMSNormalize(ISMSSongCellHeight)
        if indexPath.row == hoverRow {
            // Don't visualize moves that are not possible
            if internallyDragging, let draggedIndexPath = self.draggableTableView.dragIndexPath {
                if hoverRow == draggedIndexPath.row || hoverRow == draggedIndexPath.row - 1 {
                    return height
                }
            }
            
            // Otherwise expand it
            height += ISMSNormalize(ISMSSongCellHeight)
        }
        return height
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.playSongAtIndex(indexPath.row)
    }
}

extension PlayQueueViewController: PlayQueueViewModelDelegate {
    func itemsChanged() {
        self.tableView.reloadData()
        
        if viewModel.currentIndex > 0 && viewModel.currentIndex < viewModel.numberOfRows {
            let indexPath = IndexPath(row: self.viewModel.currentIndex, section: 0)
            if visible {
                EX2Dispatch.runInMainThread(afterDelay: 0.3) {
                    self.tableView.scrollToRow(at: indexPath, at: .top, animated: self.visible)
                }
            } else {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: self.visible)
            }
        }
    }
}

@objc class CurrentItemCell: DroppableCell, DraggableCell {
    var indexPath: IndexPath?
    var associatedObject: AnyObject? {
        didSet {
            if let song = associatedObject as? ISMSSong {
                coverArtView.coverArtId = song.coverArtId
                songLabel.text = song.title
                artistLabel.text = song.artistDisplayName
            }
        }
    }
    
    let coverArtView = AsynchronousImageView()
    let songLabel = UILabel()
    let artistLabel = UILabel()
    
    fileprivate func commonInit() {
        super.backgroundColor = .lightGray
        
        containerView.addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.top.equalTo(containerView)
            make.leading.equalTo(containerView)
            make.bottom.equalTo(containerView)
            make.width.equalTo(60)
        }
        
        songLabel.font = .systemFont(ofSize: 15)
        songLabel.textColor = .black
        containerView.addSubview(songLabel)
        songLabel.snp.makeConstraints { make in
            make.top.equalTo(containerView)
            make.leading.equalTo(coverArtView.snp.trailing).offset(5)
            make.trailing.equalTo(containerView).inset(5)
            make.height.equalTo(30)
        }
        
        artistLabel.font = .systemFont(ofSize: 13)
        artistLabel.textColor = .darkGray
        containerView.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.top.equalTo(songLabel.snp.bottom)
            make.leading.equalTo(songLabel)
            make.trailing.equalTo(songLabel)
            make.height.equalTo(20)
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    var draggable: Bool {
        return true
    }
    
    var dragItem: ISMSItem? {
        return associatedObject as? ISMSItem
    }
}
