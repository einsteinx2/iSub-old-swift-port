//
//  StoreUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "StoreUITableViewCell.h"
#import "MKStoreManager.h"

@implementation StoreUITableViewCell

@synthesize titleLabel, descLabel, priceLabel, myProduct;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		myProduct = nil;
		
		titleLabel = [[UILabel alloc] init];
		titleLabel.frame = CGRectMake(10, 10, 250, 25);
		titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
		titleLabel.font = [UIFont boldSystemFontOfSize:20];
		titleLabel.textColor = [UIColor blackColor];
		titleLabel.textAlignment = UITextAlignmentLeft;
		[self.contentView addSubview:titleLabel];
		
		descLabel = [[UILabel alloc] init];
		descLabel.frame = CGRectMake(10, 40, 310, 100);
		descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		descLabel.font = [UIFont systemFontOfSize:14];
		descLabel.textColor = [UIColor grayColor];
		descLabel.textAlignment = UITextAlignmentLeft;
		descLabel.numberOfLines = 0;
		[self.contentView addSubview:descLabel];
		
		priceLabel = [[UILabel alloc] init];
		priceLabel.frame = CGRectMake(250, 10, 60, 20);
		priceLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		priceLabel.font = [UIFont boldSystemFontOfSize:20];
		priceLabel.textColor = [UIColor redColor];
		priceLabel.textAlignment = UITextAlignmentRight;
		priceLabel.adjustsFontSizeToFitWidth = YES;
		[self.contentView addSubview:priceLabel];
	}
	
	return self;
}

- (void)dealloc 
{
	 myProduct = nil;
	
}

- (SKProduct *)myProduct
{
	@synchronized(self)
	{
		return myProduct;
	}
}

- (void)setMyProduct:(SKProduct*)product
{
	@synchronized(self)
	{
		myProduct = product;
		
		titleLabel.text = [myProduct localizedTitle];
		descLabel.text = [myProduct localizedDescription];
		
		if ([MKStoreManager isFeaturePurchased:[myProduct productIdentifier]])
		{
			priceLabel.textColor = [UIColor colorWithRed:0.0 green:.66 blue:0.0 alpha:1.0];
			priceLabel.text = @"Unlocked";
			
			self.contentView.alpha = .40;
		}
		else
		{
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
			[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
			[numberFormatter setLocale:myProduct.priceLocale];
			priceLabel.text = [numberFormatter stringFromNumber:myProduct.price];
		}
	}
}

@end
