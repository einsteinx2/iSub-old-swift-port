//
//  StoreUITableViewCell.swift
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

public class StoreUITableViewCell : UITableViewCell
{
    public var product: SKProduct? {
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
    
    public let titleLabel: UILabel = UILabel()
    public let descLabel: UILabel = UILabel()
    public let priceLabel: UILabel = UILabel()
    
    // MARK: - LifeCycle -
    
    override public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.titleLabel.frame = CGRectMake(10, 10, 250, 25)
        self.titleLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleRightMargin
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

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
