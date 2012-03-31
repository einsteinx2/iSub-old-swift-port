//
//  StoreUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <StoreKit/StoreKit.h>

@interface StoreUITableViewCell : UITableViewCell 

@property (retain) SKProduct *myProduct;

@property (retain) UILabel *titleLabel;
@property (retain) UILabel *descLabel;
@property (retain) UILabel *priceLabel;

@end
