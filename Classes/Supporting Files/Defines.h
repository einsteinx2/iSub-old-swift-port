//
//  Defines.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Defines_h
#define iSub_Defines_h

#define ISMSHeaderColor [UIColor colorWithRed:200.0/255.0 green:200.0/255.0 blue:206.0/255.0 alpha:1]
#define ISMSHeaderTextColor [UIColor colorWithRed:77.0/255.0 green:77.0/255.0 blue:77.0/255.0 alpha:1]
#define ISMSHeaderButtonColor [UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:1]

#define ISMSRegularFont(value) [UIFont fontWithName:@"HelveticaNeue" size:value]
#define ISMSBoldFont(value) [UIFont fontWithName:@"HelveticaNeue-Bold" size:value]

#define ISMSArtistFont ISMSRegularFont(16)
#define ISMSAlbumFont ISMSRegularFont(16)
#define SongFont ISMSRegularFont(16)

#define ISMSiPadBackgroundColor [UIColor colorWithRed:200.0/255.0 green:200.0/255.0 blue:206.0/255.0 alpha:1]
#define ISMSiPadCornerRadius 5.

#define ISMSBaseWidth 320.0
NS_INLINE CGFloat ISMSNormalize(CGFloat value)
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        return value;
    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat percent = (screenWidth - ISMSBaseWidth) / screenWidth;
    CGFloat normalizedValue = value * (1 + percent);
    return normalizedValue;
}

#define SongCellHeight 44.0
#define ISMSAlbumCellHeight 50.0
#define ISMSArtistCellHeight 44.0
#define ISMSCellHeaderHeight 20.0

#endif
