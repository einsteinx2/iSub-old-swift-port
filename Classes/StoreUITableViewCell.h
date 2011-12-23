//
//  StoreUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <StoreKit/StoreKit.h>

@interface StoreUITableViewCell : UITableViewCell 
{
	UILabel *titleLabel;
	UILabel *descLabel;
	UILabel *priceLabel;
	
	SKProduct *myProduct;
}

@property (nonatomic, retain) SKProduct *myProduct;

@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *descLabel;
@property (nonatomic, retain) UILabel *priceLabel;

@end
