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
    
    fileprivate let appDelegate = iSubAppDelegate.sharedInstance()
    fileprivate let settings = SavedSettings.sharedInstance()
    fileprivate let viewObjects = ViewObjectsSingleton.sharedInstance()
    
    fileprivate let reuseIdentifier = "Store Cell"
    
    fileprivate let storeManager = MKStoreManager.shared()
    fileprivate var storeItems = MKStoreManager.shared().purchasableObjects
    fileprivate var checkProductsTimer: Timer?
    
    // MARK: - Rotation -
    
    override var shouldAutorotate : Bool {
        if settings.isRotationLockEnabled && UIDevice.current.orientation != .portrait {
            return false
        }
    
        return true
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        self.tableView.reloadData()
    }
    
    // MARK: - LifeCycle -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(StoreViewController.storePurchaseComplete), name: NSNotification.Name(rawValue: ISMSNotification_StorePurchaseComplete), object: nil)

        if storeItems?.count == 0 {
            viewObjects?.showAlbumLoadingScreen(appDelegate?.window, sender: self)
            checkProductsTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(StoreViewController.checkProducts), userInfo: nil, repeats: true)
            checkProducts()
        } else {
            organizeList()
            self.tableView.reloadData()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: ISMSNotification_StorePurchaseComplete), object: nil)
    }
    
    // MARK: - Notifications -
    
    @objc fileprivate func storePurchaseComplete() {
        self.tableView.reloadData()
    }
    
    // MARK: - Actions -
    
    func checkProducts() {
        storeItems = storeManager?.purchasableObjects
    
        if (storeItems?.count)! > 0 {
            checkProductsTimer?.invalidate()
            checkProductsTimer = nil
    
            viewObjects?.hideLoadingScreen()
    
            organizeList()
            
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Loading -
    
    func cancelLoad() {
        checkProductsTimer?.invalidate()
        checkProductsTimer = nil
        
        viewObjects?.hideLoadingScreen()
    }

    func organizeList() {
        // Place purchased products at the the end of the list
        let sorted: NSMutableArray = []
        let purchased: NSMutableArray = []
        
        for item in storeItems! {
            if MKStoreManager.isFeaturePurchased((item as AnyObject).productIdentifier) {
                purchased.add(item)
            } else {
                sorted.add(item)
            }
        }
        
        sorted.addObjects(from: purchased as [AnyObject])
        
        storeItems = sorted
    }
}

// MARK: - Table view data source

extension StoreViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? 75.0 : 150.0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storeItems!.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "NoReuse")
            cell.textLabel?.text = "Restore previous purchases"
            
            return cell
        } else {
            let adjustedRow = indexPath.row - 1
            let cell = StoreTableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "NoReuse")
            cell.product = (storeItems?[adjustedRow] as! SKProduct)
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            storeManager?.restorePreviousTransactions(onComplete: nil, onError: nil)
        } else {
            let adjustedRow = indexPath.row - 1
            let product: SKProduct = storeItems![adjustedRow] as! SKProduct
            let identifier: String = product.productIdentifier
    
            if !MKStoreManager.isFeaturePurchased(identifier) {
                storeManager?.buyFeature(identifier, onComplete: nil, onCancelled: nil)
                
                _ = self.navigationController?.popToRootViewController(animated: true)
            }
        }
    
        self.tableView.deselectRow(at: indexPath, animated: true)
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
                    let numberFormatter = NumberFormatter()
                    numberFormatter.formatterBehavior = NumberFormatter.Behavior.behavior10_4
                    numberFormatter.numberStyle = NumberFormatter.Style.currency
                    numberFormatter.locale = product.priceLocale
                    self.priceLabel.text = numberFormatter.string(from: product.price)
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
        
        self.titleLabel.frame = CGRect(x: 10, y: 10, width: 250, height: 25)
        self.titleLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleRightMargin]
        self.titleLabel.font = ISMSBoldFont(20)
        self.titleLabel.textColor = UIColor.black
        self.titleLabel.textAlignment = NSTextAlignment.left
        self.contentView.addSubview(self.titleLabel)
        
        self.descLabel.frame = CGRect(x: 10, y: 40, width: 310, height: 100)
        self.descLabel.autoresizingMask = UIViewAutoresizing.flexibleWidth
        self.descLabel.font = ISMSRegularFont(14)
        self.descLabel.textColor = UIColor.gray
        self.descLabel.textAlignment = NSTextAlignment.left
        self.descLabel.numberOfLines = 0
        self.contentView.addSubview(self.descLabel)
        
        self.priceLabel.frame = CGRect(x: 250, y: 10, width: 60, height: 20)
        self.priceLabel.autoresizingMask = UIViewAutoresizing.flexibleLeftMargin
        self.priceLabel.font = ISMSBoldFont(20)
        self.priceLabel.textColor = UIColor.red
        self.priceLabel.textAlignment = NSTextAlignment.right
        self.priceLabel.adjustsFontSizeToFitWidth = true
        self.contentView.addSubview(self.priceLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
