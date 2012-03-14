//
//  HelpTabViewController.h
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface HelpTabViewController : UIViewController <UIWebViewDelegate>

@property (retain) IBOutlet UIWebView *helpWebView;
@property (retain) IBOutlet UIActivityIndicatorView *loadingIndicator;

@end
