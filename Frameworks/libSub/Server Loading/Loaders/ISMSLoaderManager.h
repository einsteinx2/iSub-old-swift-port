//
//  LoaderManager.h
//  iSub
//
//  Created by Ben Baron on 9/24/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

@protocol ApiLoaderDelegate;
@protocol ApiLoaderManager <NSObject>

@required
- (id)initWithDelegate:(NSObject <ApiLoaderDelegate> *)theDelegate;
- (void)startLoad;
- (void)cancelLoad;

@end
