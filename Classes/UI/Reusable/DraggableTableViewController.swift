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
//        if SavedSettings.si.isRotationLockEnabled && UIDevice.current.orientation != .portrait {
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
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(setupLeftBarButton), name: NSNotification.Name.UIApplicationDidBecomeActive)
        
        setupRefreshControl()
        
        customizeTableView(tableView)
        
        // Keep the table rows from showing past the bottom
        if tableView.tableFooterView == nil {
            tableView.tableFooterView = UIView()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.tableView.tableHeaderView == nil, let headerView = setupHeaderView(width: self.tableView.frame.size.width) {
            setAndLayoutTableHeaderView(header: headerView)
        }
        
        self.view.backgroundColor = UIColor(white: 0.3, alpha: 1)
        self.navigationItem.leftBarButtonItem = setupLeftBarButton()
        self.navigationItem.rightBarButtonItem = setupRightBarButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        async(after: 0.5) {
            self.tableView.tableHeaderView = self.tableView.tableHeaderView
        }
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.UIApplicationDidBecomeActive)
    }
    
    // MARK: - UI -
    
    // MARK: Initial Setup
    
    // Set the tableHeaderView so that the required height can be determined, update the header's frame and set it again
    // https://stackoverflow.com/a/28102175/299262
    fileprivate func setAndLayoutTableHeaderView(header: UIView) {
        self.tableView.tableHeaderView = header
        header.setNeedsLayout()
        header.layoutIfNeeded()
        header.frame.size = header.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        self.tableView.tableHeaderView = header
    }
    
    func setupHeaderView(width: CGFloat) -> UIView? {
        // Override to provide a custom header
        return nil
    }
    
    func customizeTableView(_ tableView: UITableView) {
        
    }

    @objc func setupLeftBarButton() -> UIBarButtonItem {
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
            refreshControl.attributedTitle = NSAttributedString(string: "Pull down to reload...", attributes: [NSAttributedStringKey.foregroundColor: tintColor])
            refreshControl.tintColor = tintColor
            refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
            self.refreshControl = refreshControl
        }
    }
    
    @objc func didPullToRefresh() {
        fatalError("didPullToRefresh must be overridden")
    }
    
    // MARK - Actions -
    
    @objc func popViewController() {
        if self.navigationController?.viewControllers.count ?? 0 <= 2 {
            _ = self.navigationController?.popViewController(animated: true)
        } else if let navigationController = self.navigationController as? NavigationStack {
            navigationController.showControllers()
        }
    }
    
    @objc func showMenu() {
        self.sidePanelController?.showLeftPanel(animated: true)
    }
    
    @objc func showPlayQueue() {
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
