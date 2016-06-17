//
//  DraggableTableViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 5/17/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import JASidePanels
import libSub

class DraggableTableViewController: UITableViewController {
    
    var draggableTableView: DraggableTableView {
        return self.tableView as! DraggableTableView
    }
    
    // MARK: - Rotation -
    
    override func shouldAutorotate() -> Bool {
        if SavedSettings.sharedInstance().isRotationLockEnabled && UIDevice.currentDevice().orientation != .Portrait {
            return false
        }
        
        return true
    }
    
    // MARK: - Lifecycle -
    
    override func loadView() {
        super.loadView()
        
        self.tableView = DraggableTableView()
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.barStyle = .Black
        self.edgesForExtendedLayout = .None
        
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(DraggableTableViewController.jukeboxToggled(_:)), name: ISMSNotification_JukeboxEnabled, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(DraggableTableViewController.jukeboxToggled(_:)), name: ISMSNotification_JukeboxDisabled, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(DraggableTableViewController.setupLeftBarButton), name: UIApplicationDidBecomeActiveNotification, object: nil)
        
        setupRefreshControl()
        
        if IS_IPAD() {
            self.view.backgroundColor = ISMSiPadBackgroundColor
        }
        
        self.tableView.tableHeaderView = setupHeaderView()
        // Keep the table rows from showing past the bottom
        if tableView.tableFooterView == nil {
            tableView.tableFooterView = UIView()
        }
        customizeTableView(tableView)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        updateBackgroundColor()
        
        self.navigationItem.leftBarButtonItem = setupLeftBarButton()
        self.navigationItem.rightBarButtonItem = setupRightBarButton()
    }
    
    deinit {
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_JukeboxEnabled, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_JukeboxDisabled, object: nil)
        NSNotificationCenter.removeObserverOnMainThread(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    // MARK: - Private -
    
    private func updateBackgroundColor() {
        self.view.backgroundColor = SavedSettings.sharedInstance().isJukeboxEnabled ? ViewObjectsSingleton.sharedInstance().jukeboxColor : ViewObjectsSingleton.sharedInstance().windowColor
    }
    
    // MARK: Notifications
    
    @objc private func jukeboxToggled(notification: NSNotification) {
        self.updateBackgroundColor()
    }
    
    // MARK: - UI -
    
    // MARK: Initial Setup
    
    func setupHeaderView() -> UIView? {
        // Override to provide a custom header
        return nil
    }
    
    func customizeTableView(tableView: UITableView) {
        
    }

    func setupLeftBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(title: "Back",
                               style: .Plain,
                               target: self,
                               action: #selector(DraggableTableViewController.popViewController))
    }

    func setupRightBarButton() -> UIBarButtonItem? {
        if !IS_IPAD() {
            return UIBarButtonItem(image: UIImage(named: "now-playing"),
                                   style: .Plain,
                                   target: self,
                                   action: #selector(DraggableTableViewController.showPlayQueue))
        } else {
            return nil
        }
    }
    
    // MARK: Pull to Refresh
    
    func shouldSetupRefreshControl() -> Bool {
        return false
    }
    
    func setupRefreshControl() {
        if shouldSetupRefreshControl() && self.refreshControl == nil {
            let refreshControl = UIRefreshControl()
            let tintColor = UIColor.whiteColor()
            refreshControl.attributedTitle = NSAttributedString(string: "Pull down to reload...", attributes: [NSForegroundColorAttributeName: tintColor])
            refreshControl.tintColor = tintColor
            refreshControl.addTarget(self, action: #selector(DraggableTableViewController.didPullToRefresh), forControlEvents: .ValueChanged)
            self.refreshControl = refreshControl
        }
    }
    
    func didPullToRefresh() {
        fatalError("didPullToRefresh must be overridden")
    }
    
    // MARK: Other
    
    func showDeleteToggles() {
        // Show the delete toggle for already visible cells
        UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseIn, animations: {
            for cell in self.tableView.visibleCells {
                if let cell = cell as? ItemTableViewCell {
                    cell.showDeleteCheckbox()
                }
            }
        }, completion: nil)
    }
    
    func hideDeleteToggles() {
        // Hide the delete toggle for already visible cells
        for cell in self.tableView.visibleCells {
            if let cell = cell as? ItemTableViewCell {
                cell.hideDeleteCheckbox()
            }
        }
    }
    
    func markCellAsPlayingAtIndexPath(indexPath: NSIndexPath) {
        for cell in self.tableView.visibleCells {
            if let cell = cell as? ItemTableViewCell {
                cell.playing = false
            }
        }
        
        if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ItemTableViewCell {
            cell.playing = true
        }
    }
    
    // MARK - Actions -
    
    func popViewController() {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func showMenu() {
        self.sidePanelController?.showLeftPanelAnimated(true)
    }
    
    func showPlayQueue() {
        self.sidePanelController?.showRightPanelAnimated(true)
    }
    
    // MARK - Table View Delegate -
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        // Remove seperator inset
        cell.separatorInset = UIEdgeInsetsZero
        
        // Prevent the cell from inheriting the Table View's margin settings
        cell.preservesSuperviewLayoutMargins = false
        
        // Explictly set the cell's layout margins
        cell.layoutMargins = UIEdgeInsetsZero
    }
}