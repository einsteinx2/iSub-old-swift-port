//
//  StoreViewController.swift
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

class StoreViewController : DraggableTableViewController {
    
    private let appDelegate = iSubAppDelegate.sharedInstance()
    private let settings = SavedSettings.sharedInstance()
    private let viewObjects = ViewObjectsSingleton.sharedInstance()
    
    private let reuseIdentifier = "Store Cell"
    
    private let storeManager = MKStoreManager.sharedManager()
    private var storeItems = MKStoreManager.sharedManager().purchasableObjects
    private var checkProductsTimer: NSTimer?
    
    // MARK: - Rotation -
    
    override func shouldAutorotate() -> Bool {
        if settings.isRotationLockEnabled && UIDevice.currentDevice().orientation != .Portrait {
            return false
        }
    
        return true
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        self.tableView.reloadData()
    }
    
    // MARK: - LifeCycle -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(StoreViewController.storePurchaseComplete), name: ISMSNotification_StorePurchaseComplete, object: nil)

        if storeItems.count == 0 {
            viewObjects.showAlbumLoadingScreen(appDelegate.window, sender: self)
            checkProductsTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(StoreViewController.checkProducts), userInfo: nil, repeats: true)
            checkProducts()
        } else {
            organizeList()
            self.tableView.reloadData()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ISMSNotification_StorePurchaseComplete, object: nil)
    }
    
    // MARK: - Notifications -
    
    @objc private func storePurchaseComplete() {
        self.tableView.reloadData()
    }
    
    // MARK: - Actions -
    
    func checkProducts() {
        storeItems = storeManager.purchasableObjects
    
        if storeItems.count > 0 {
            checkProductsTimer?.invalidate()
            checkProductsTimer = nil
    
            viewObjects.hideLoadingScreen()
    
            organizeList()
            
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Loading -
    
    func cancelLoad() {
        checkProductsTimer?.invalidate()
        checkProductsTimer = nil
        
        viewObjects.hideLoadingScreen()
    }

    func organizeList() {
        // Place purchased products at the the end of the list
        let sorted: NSMutableArray = []
        let purchased: NSMutableArray = []
        
        for item in storeItems {
            if MKStoreManager.isFeaturePurchased(item.productIdentifier) {
                purchased.addObject(item)
            } else {
                sorted.addObject(item)
            }
        }
        
        sorted.addObjectsFromArray(purchased as [AnyObject])
        
        storeItems = sorted
    }
}

// MARK: - Table view data source

extension StoreViewController {
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath.row == 0 ? 75.0 : 150.0
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storeItems.count + 1
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "NoReuse")
            cell.textLabel?.text = "Restore previous purchases"
            
            return cell
        } else {
            let adjustedRow = indexPath.row - 1
            let cell = StoreTableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "NoReuse")
            cell.product = (storeItems[adjustedRow] as! SKProduct)
            
            return cell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == 0 {
            storeManager.restorePreviousTransactionsOnComplete(nil, onError: nil)
        } else {
            let adjustedRow = indexPath.row - 1
            let product: SKProduct = storeItems[adjustedRow] as! SKProduct
            let identifier: String = product.productIdentifier
    
            if !MKStoreManager.isFeaturePurchased(identifier) {
                storeManager.buyFeature(identifier, onComplete: nil, onCancelled: nil)
                
                self.navigationController?.popToRootViewControllerAnimated(true)
            }
        }
    
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

private class StoreTableViewCell : UITableViewCell
{
    var product: SKProduct? {
        didSet {
            if let product = product {
                self.titleLabel.text = product.localizedTitle
                self.descLabel.text = product.localizedDescription
                
                if MKStoreManager.isFeaturePurchased(product.productIdentifier) {
                    self.priceLabel.textColor = UIColor(red: 0.0, green: 0.66, blue: 0.0, alpha: 1.0)
                    self.priceLabel.text = "Unlocked"
                    self.contentView.alpha = 0.40
                } else {
                    let numberFormatter = NSNumberFormatter()
                    numberFormatter.formatterBehavior = NSNumberFormatterBehavior.Behavior10_4
                    numberFormatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle
                    numberFormatter.locale = product.priceLocale
                    self.priceLabel.text = numberFormatter.stringFromNumber(product.price)
                }
            }
        }
    }
    
    let titleLabel: UILabel = UILabel()
    let descLabel: UILabel = UILabel()
    let priceLabel: UILabel = UILabel()
    
    // MARK: - LifeCycle -
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.titleLabel.frame = CGRectMake(10, 10, 250, 25)
        self.titleLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleRightMargin]
        self.titleLabel.font = ISMSBoldFont(20)
        self.titleLabel.textColor = UIColor.blackColor()
        self.titleLabel.textAlignment = NSTextAlignment.Left
        self.contentView.addSubview(self.titleLabel)
        
        self.descLabel.frame = CGRectMake(10, 40, 310, 100)
        self.descLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        self.descLabel.font = ISMSRegularFont(14)
        self.descLabel.textColor = UIColor.grayColor()
        self.descLabel.textAlignment = NSTextAlignment.Left
        self.descLabel.numberOfLines = 0
        self.contentView.addSubview(self.descLabel)
        
        self.priceLabel.frame = CGRectMake(250, 10, 60, 20)
        self.priceLabel.autoresizingMask = UIViewAutoresizing.FlexibleLeftMargin
        self.priceLabel.font = ISMSBoldFont(20)
        self.priceLabel.textColor = UIColor.redColor()
        self.priceLabel.textAlignment = NSTextAlignment.Right
        self.priceLabel.adjustsFontSizeToFitWidth = true
        self.contentView.addSubview(self.priceLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
