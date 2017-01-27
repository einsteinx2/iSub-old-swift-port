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

    var hoverRow = Int.min
    
    fileprivate let viewModel: PlayQueueViewModel
    fileprivate let currentItemReuseIdentifier = "Current Item Cell"
    fileprivate let itemReuseIdentifier = "Item Cell"
    fileprivate var internallyDragging = false
    fileprivate var visible: Bool {
        return self.sidePanelController.state == JASidePanelRightVisible
    }
    
    fileprivate let singleTapRecognizer = UITapGestureRecognizer()
    fileprivate let doubleTapRecognizer = UITapGestureRecognizer()
    
    init(viewModel: PlayQueueViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        self.viewModel.delegate = self
        self.draggableTableView.dimDraggedCells = false
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingMoved(_:)), name: DraggableTableView.Notifications.draggingMoved)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingBegan)
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingMoved)
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingEnded)
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingCanceled)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.adjustFooter()
        scrollCurrentSongToTop()
    }
    
    fileprivate func scrollCurrentSongToTop() {
        adjustFooter()
        let currentIndex = self.viewModel.currentIndex
        if currentIndex >= 0 && currentIndex < viewModel.numberOfRows {
            let indexPath = IndexPath(row: self.viewModel.currentIndex, section: 0)
            if visible {
                DispatchQueue.main.async(after: 0.2) {
                    self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                }
            } else {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            }
        }
    }
    
    // MARK - Drag and Drop -
    
    @objc fileprivate func draggingBegan(_ notification: Notification) {
        singleTapRecognizer.isEnabled = false
        doubleTapRecognizer.isEnabled = false
        
        if let userInfo = notification.userInfo, let dragSourceTableView = userInfo[DraggableTableView.Notifications.Keys.dragSourceTableView] as? DraggableTableView, let dragCell = userInfo[DraggableTableView.Notifications.Keys.dragCell] as? DraggableCell {
            
            internallyDragging = (dragSourceTableView == self.tableView)
            if internallyDragging, let indexPath = dragCell.indexPath {
                dragCell.containerView.isHidden = true
                hoverRow = indexPath.row
                
                // Reload cell heights
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        } else {
            internallyDragging = false
        }
    }
    
    @objc fileprivate func draggingMoved(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let dragCell = userInfo[DraggableTableView.Notifications.Keys.dragCell] as? DraggableCell, dragCell.dragItem is Song,
                let location = userInfo[DraggableTableView.Notifications.Keys.location] as? NSValue {
                currentTouchLocation = location.cgPointValue
                if !isAutoScrolling {
                    handleDrag(atLocation: currentTouchLocation)
                }
                
                if currentTouchLocation.y < CGFloat(50) {
                    startAutoScroll(up: true)
                } else if currentTouchLocation.y > self.tableView.frame.size.height - CGFloat(50) {
                    startAutoScroll(up: false)
                } else {
                    stopAutoScroll()
                }
            }
        }
    }
    
    @objc fileprivate func draggingEnded(_ notification: Notification) {
        stopAutoScroll()
        
        if visible, let userInfo = notification.userInfo {
            if let dragCell = userInfo[DraggableTableView.Notifications.Keys.dragCell] as? DraggableCell,
                   let song = dragCell.dragItem as? Song,
                   let location = userInfo[DraggableTableView.Notifications.Keys.location] as? NSValue {
                
                let point = location.cgPointValue
                let localPoint = self.view.convert(point, from: nil)
                if self.view.bounds.contains(localPoint) {
                    if internallyDragging, let fromIndex = self.draggableTableView.dragIndexPath?.row {
                        let toIndex = hoverRow + 1
                        if fromIndex != toIndex {
                            viewModel.moveSong(fromIndex: fromIndex, toIndex: toIndex)
                        }
                    } else if !internallyDragging {
                        viewModel.insertSong(song, atIndex: hoverRow + 1)
                    }
                }
            }
        }
        
        hoverRow = Int.min
        self.tableView.reloadData()
        adjustFooter()
        
        singleTapRecognizer.isEnabled = true
        doubleTapRecognizer.isEnabled = true
    }
    
    @objc fileprivate func draggingCanceled(_ notification: Notification) {
        stopAutoScroll()

        hoverRow = Int.min
        self.tableView.reloadData()
        
        singleTapRecognizer.isEnabled = true
        doubleTapRecognizer.isEnabled = true
    }
    
    fileprivate var currentTouchLocation = CGPoint()
    fileprivate var isAutoScrolling = false
    fileprivate var autoScrollAnimationId: INTUAnimationID?
    
    fileprivate func startAutoScroll(up: Bool) {
        if !isAutoScrolling {
            isAutoScrolling = true
            
            // Reload cell heights
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            
            let startOffset = self.tableView.contentOffset
            var endOffset = CGPoint()
            if !up {
                let bottomCellRect = self.tableView.rectForRow(at: IndexPath(row: viewModel.numberOfRows - 1, section: 0))
                let bottomY = bottomCellRect.origin.y + bottomCellRect.size.height + CGFloat(100)
                endOffset = CGPoint(x: 0, y: bottomY - self.tableView.frame.size.height)
            }
            
            let timelineAnimationSpeed = 500.0
            let timelineAnimationDuration = Double(fabs(endOffset.y - startOffset.y)) / timelineAnimationSpeed
            
            func animations(progress: CGFloat) {
                self.tableView.contentOffset = INTUInterpolateCGPoint(startOffset, endOffset, progress);
            }
            
            func completion(success: Bool) {
                self.autoScrollAnimationId = nil
                self.stopAutoScroll()
            }
            
            autoScrollAnimationId = INTUAnimationEngine.animate(withDuration: timelineAnimationDuration, delay: 0.0, easing: INTULinear, animations: animations, completion: completion)
        }
    }
    
    fileprivate func stopAutoScroll() {
        isAutoScrolling = false
        if let autoScrollAnimationId = autoScrollAnimationId {
            INTUAnimationEngine.cancelAnimation(withID: autoScrollAnimationId)
        }
    }
    
    fileprivate func handleDrag(atLocation location: CGPoint) {
        // Treat hovers over the top portion of the cell as the previous cell
        var point = location
        point.y -= (ISMSNormalize(CellHeight) * 0.75)
        let tablePoint = tableView.convert(point, from: nil)
        
        let indexPath = tableView.indexPathForRow(at: tablePoint)
        var row = -1
        if let indexPath = indexPath {
            row = indexPath.row
        } else {
            // If we're at the end of the table, treat it as the last cell
            let lastRow = tableView.numberOfRows(inSection: 0) - 1
            if lastRow >= 0 {
                let lastCellIndexPath = IndexPath(row: lastRow, section: 0)
                let lastCellRect = tableView.rectForRow(at: lastCellIndexPath)
                if tablePoint.y > lastCellRect.origin.y + lastCellRect.size.height {
                    row = lastRow
                }
            } else {
                // Empty table
                row = 0
            }
        }
        
        if hoverRow != row {
            hoverRow = row
            
            // TODO: Fix this weird bug where if you drag around the top cell, a cell near the bottom opens and closes
            //Swift.print("reloading cell heights, hoverRow: \(hoverRow)")
            
            // Reload cell heights
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
    
    override func customizeTableView(_ tableView: UITableView) {
        tableView.allowsSelection = false
        
        doubleTapRecognizer.addTarget(self, action: #selector(doubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        tableView.addGestureRecognizer(doubleTapRecognizer)
        
        singleTapRecognizer.addTarget(self, action: #selector(singleTap(_:)))
        singleTapRecognizer.numberOfTapsRequired = 1
        singleTapRecognizer.numberOfTouchesRequired = 1
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        tableView.addGestureRecognizer(singleTapRecognizer)
        
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 0))
        adjustFooter()
        tableView.backgroundColor = UIColor.clear
        tableView.separatorColor = UIColor.black
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: itemReuseIdentifier)
        tableView.register(CurrentItemCell.self, forCellReuseIdentifier: currentItemReuseIdentifier)
    }
    
    fileprivate let minFooterSize: CGFloat = 100
    fileprivate func adjustFooter() {
        guard viewModel.currentIndex >= 0 && viewModel.currentIndex < viewModel.numberOfRows else {
            if let footerView = tableView.tableFooterView {
                footerView.frame.size.height = minFooterSize
                tableView.tableFooterView = footerView
            }
            return
        }
        
        // Keep the footer the correct height to allow the player to sit at the top but no further
        let currentSongRect = self.tableView.rectForRow(at: IndexPath(row: viewModel.currentIndex, section: 0))
        let lastRowRect = self.tableView.rectForRow(at: IndexPath(row: viewModel.numberOfRows - 1, section: 0))
        
        let tableHeight = lastRowRect.origin.y + lastRowRect.size.height
        let distanceToEndOfTable = tableHeight - currentSongRect.origin.y
        
        var footerHeight = UIScreen.main.bounds.height - distanceToEndOfTable
        if footerHeight < minFooterSize {
            footerHeight = minFooterSize
        }
        
        if let footerView = tableView.tableFooterView {
            footerView.frame.size.height = footerHeight
            tableView.tableFooterView = footerView
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        if row == viewModel.currentIndex, let cell = tableView.dequeueReusableCell(withIdentifier: currentItemReuseIdentifier, for: indexPath) as? CurrentItemCell {
            cell.containerView.isHidden = (self.draggableTableView.isDraggingCell && self.draggableTableView.dragIndexPath == indexPath)
            cell.cellHeight = 64.0
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.indexPath = indexPath
            cell.associatedObject = viewModel.song(atIndex: indexPath.row)
            
            return cell
        } else if let cell = tableView.dequeueReusableCell(withIdentifier: itemReuseIdentifier, for: indexPath) as? ItemTableViewCell {
            cell.containerView.isHidden = (self.draggableTableView.isDraggingCell && self.draggableTableView.dragIndexPath == indexPath)
            cell.alwaysShowSubtitle = true
            cell.cellHeight = ISMSNormalize(CellHeight)
            cell.accessoryType = .none
            cell.selectionStyle = .none
            
            let song = viewModel.song(atIndex: indexPath.row)
            cell.associatedObject = song
            cell.coverArtId = nil
            cell.title = song.title
            cell.subTitle = song.artistDisplayName
            cell.duration = song.duration
            
            return cell
        }
        
        // Should never happen
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height = indexPath.row == viewModel.currentIndex ? 64.0 : ISMSNormalize(CellHeight)
        if internallyDragging, self.draggableTableView.isDraggingCell, let draggedIndexPath = self.draggableTableView.dragIndexPath, indexPath.row == draggedIndexPath.row {
            height = 0
        }
        
        if !isAutoScrolling && indexPath.row == hoverRow + 1 {
            height += ISMSNormalize(CellHeight)
        }
        
        return height
    }
    
    @objc fileprivate func singleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let point = recognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            let song = self.viewModel.song(atIndex: indexPath.row)
            showActionSheet(item: song, indexPath: indexPath)
        }
    }
    
    @objc fileprivate func doubleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let point = recognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            viewModel.playSong(atIndex: indexPath.row)
        }
    }
    
    fileprivate func showActionSheet(item: Item, indexPath: IndexPath) {
        if item is Song {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            alertController.addAction(UIAlertAction(title: "Play", style: .default) { action in
                self.viewModel.playSong(atIndex: indexPath.row)
            })
            
            let currentIndex = viewModel.currentIndex
            if indexPath.row != currentIndex {
                alertController.addAction(UIAlertAction(title: "Play Next", style: .default) { action in
                    let toIndex = IndexPath(row: currentIndex + 1, section: 0)
                    self.viewModel.moveSong(fromIndex: indexPath.row, toIndex: toIndex.row)
                    self.tableView.moveRow(at: indexPath, to: toIndex)
                })
            }
            
            alertController.addAction(UIAlertAction(title: "Remove", style: .destructive) { action in
                self.viewModel.removeSong(atIndex: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .right)
            })
            
            alertController.addAction(UIAlertAction(title: "Clear Play Queue", style: .destructive) { action in
                self.viewModel.clearPlayQueue()
            })
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

extension PlayQueueViewController: PlayQueueViewModelDelegate {
    func itemsChanged() {
        self.tableView.reloadData()
    }
    
    func currentIndexChanged() {
        // Do nothing because this can happen during rearranging cells
    }
    
    func currentSongChanged() {
        // Only scroll to top when the playing song changes
        self.tableView.reloadData()
        scrollCurrentSongToTop()
    }
}

@objc class CurrentItemCell: DroppableCell, DraggableCell {
    var indexPath: IndexPath?
    var associatedObject: Any? {
        didSet {
            if let song = associatedObject as? Song {
                if let coverArtId = song.coverArtId {
                    coverArtView.loadImage(coverArtId: coverArtId, size: .cell)
                } else {
                    coverArtView.setDefaultImage(forSize: .cell)
                }
                songLabel.text = song.title
                artistLabel.text = song.artistDisplayName
            }
        }
    }
    
    let coverArtView = CachedImageView()
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
    
    var isDraggable: Bool {
        return true
    }
    
    var dragItem: Item? {
        return associatedObject as? Item
    }
}
