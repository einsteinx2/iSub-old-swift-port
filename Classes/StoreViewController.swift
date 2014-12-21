//
//  StoreViewController.swift
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class StoreViewController : CustomUITableViewController {
    
    private lazy var _appDelegate = iSubAppDelegate.sharedInstance()
    private let _settings = SavedSettings.sharedInstance()
    private let _viewObjects = ViewObjectsSingleton.sharedInstance()
    
    private let _reuseIdentifier = "Store Cell"
    
    private let _storeManager: MKStoreManager = MKStoreManager.sharedManager()
    private var _storeItems: [AnyObject] = MKStoreManager.sharedManager().purchasableObjects
    private var _checkProductsTimer: NSTimer?
    
    // MARK: - Rotation -
    
    public override func shouldAutorotate() -> Bool {
        if _settings.isRotationLockEnabled && UIDevice.currentDevice().orientation != UIDeviceOrientation.Portrait {
            return false
        }
    
        return true
    }
    
    public override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        self.tableView.reloadData()
    }
    
    // MARK: - LifeCycle -
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_storePurchaseComplete:", name: ISMSNotification_StorePurchaseComplete, object: nil)

        if _storeItems.count == 0 {
            _viewObjects.showAlbumLoadingScreen(_appDelegate.window, sender: self)
            self._checkProductsTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "a_checkProducts", userInfo: nil, repeats: true)
            self.a_checkProducts(nil)
        } else {
            self._organizeList()
            self.tableView.reloadData()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ISMSNotification_StorePurchaseComplete, object: nil)
    }
    
    // MARK: - Notifications -
    
    func _storePurchaseComplete(notification: NSNotification?) {
        self.tableView.reloadData()
    }
    
    // MARK: - Actions -
    
    func a_checkProducts(sender: AnyObject?) {
        _storeItems = _storeManager.purchasableObjects
    
        if _storeItems.count > 0 {
            _checkProductsTimer?.invalidate()
            _checkProductsTimer = nil
    
            _viewObjects.hideLoadingScreen()
    
            self._organizeList()
            
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Loading -
    
    public func cancelLoad() {
        _checkProductsTimer?.invalidate()
        _checkProductsTimer = nil
        
        _viewObjects.hideLoadingScreen()
    }

    func _organizeList() {
        // Place purchased products at the the end of the list
        var sorted: [SKProduct] = []
        var purchased: [SKProduct] = []
        
        for item in _storeItems {
            if let product = item as? SKProduct {
                var array = MKStoreManager.isFeaturePurchased(product.productIdentifier) ? purchased : sorted
                array.append(product)
            }
        }
        
        sorted.extend(purchased)
        
        _storeItems = sorted
    }
}

// MARK: - Table view data source

extension StoreViewController : UITableViewDelegate, UITableViewDataSource {
    
    public override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath.row == 0 ? 75.0 : 150.0
    }
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _storeItems.count + 1
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "NoReuse")
            cell.textLabel?.text = "Restore previous purchases"
            
            return cell
        } else {
            let adjustedRow = indexPath.row - 1
            let cell = StoreUITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "NoReuse")
            cell.product = _storeItems[adjustedRow] as? SKProduct
            
            return cell
        }
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == 0 {
            _storeManager.restorePreviousTransactions()
        } else {
            let adjustedRow = indexPath.row - 1
            let product: SKProduct = _storeItems[adjustedRow] as SKProduct
            let identifier: String = product.productIdentifier
    
            if !MKStoreManager.isFeaturePurchased(identifier) {
                _storeManager.buyFeature(identifier)
                
                self.navigationController?.popToRootViewControllerAnimated(true)
            }
        }
    
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}