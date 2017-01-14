//
//  DraggableTableViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 5/17/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class DraggableTableViewController: UITableViewController {
    
    var draggableTableView: DraggableTableView {
        return self.tableView as! DraggableTableView
    }
    
    // MARK: - Rotation -
    
    override var shouldAutorotate : Bool {
//        if SavedSettings.si().isRotationLockEnabled && UIDevice.current.orientation != .portrait {
//            return false
//        }
//        
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
        
        self.navigationController?.navigationBar.barStyle = .black
        self.edgesForExtendedLayout = UIRectEdge()
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(DraggableTableViewController.setupLeftBarButton), name: NSNotification.Name.UIApplicationDidBecomeActive.rawValue, object: nil)
        
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.backgroundColor = UIColor(white: 0.3, alpha: 1)
        self.navigationItem.leftBarButtonItem = setupLeftBarButton()
        self.navigationItem.rightBarButtonItem = setupRightBarButton()
    }
    
    deinit {
        NotificationCenter.removeObserver(onMainThread: self, name: NSNotification.Name.UIApplicationDidBecomeActive.rawValue, object: nil)
    }
    
    // MARK: - UI -
    
    // MARK: Initial Setup
    
    func setupHeaderView() -> UIView? {
        // Override to provide a custom header
        return nil
    }
    
    func customizeTableView(_ tableView: UITableView) {
        
    }

    func setupLeftBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(popViewController))
    }

    func setupRightBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(named: "now-playing"), style: .plain, target: self, action: #selector(showPlayQueue))
    }
    
    // MARK: Pull to Refresh
    
    func shouldSetupRefreshControl() -> Bool {
        return false
    }
    
    func setupRefreshControl() {
        if shouldSetupRefreshControl() && self.refreshControl == nil {
            let refreshControl = UIRefreshControl()
            let tintColor = UIColor.white
            refreshControl.attributedTitle = NSAttributedString(string: "Pull down to reload...", attributes: [NSForegroundColorAttributeName: tintColor])
            refreshControl.tintColor = tintColor
            refreshControl.addTarget(self, action: #selector(DraggableTableViewController.didPullToRefresh), for: .valueChanged)
            self.refreshControl = refreshControl
        }
    }
    
    func didPullToRefresh() {
        fatalError("didPullToRefresh must be overridden")
    }
    
    // MARK - Actions -
    
    func popViewController() {
        if self.navigationController?.viewControllers.count ?? 0 <= 2 {
            _ = self.navigationController?.popViewController(animated: true)
        } else if let navigationController = self.navigationController as? NavigationStack {
            navigationController.showControllers()
        }
    }
    
    func showMenu() {
        self.sidePanelController?.showLeftPanel(animated: true)
    }
    
    func showPlayQueue() {
        self.sidePanelController?.showRightPanel(animated: true)
    }
    
    // MARK - Table View Delegate -
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Remove seperator inset
        cell.separatorInset = UIEdgeInsets.zero
        
        // Prevent the cell from inheriting the Table View's margin settings
        cell.preservesSuperviewLayoutMargins = false
        
        // Explictly set the cell's layout margins
        cell.layoutMargins = UIEdgeInsets.zero
    }
}
