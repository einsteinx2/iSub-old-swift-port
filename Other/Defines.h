//
//  Defines.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Defines_h
#define iSub_Defines_h

#define ISMSJukeboxTimeout 60.0

#define ISMSHeaderColor [UIColor colorWithRedInt:200 greenInt:200 blueInt:206 alpha:1]
#define ISMSHeaderTextColor [UIColor colorWithRedInt:77 greenInt:77 blueInt:77 alpha:1]
#define ISMSHeaderButtonColor [UIColor colorWithRedInt:0 greenInt:122 blueInt:255 alpha:1]

#define ISMSRegularFont(value) [UIFont fontWithName:@"HelveticaNeue" size:value]
#define ISMSBoldFont(value) [UIFont fontWithName:@"HelveticaNeue-Bold" size:value]

#define ISMSArtistFont ISMSRegularFont(16)
#define ISMSAlbumFont ISMSRegularFont(16)
#define ISMSSongFont ISMSRegularFont(16)

#define ISMSiPadBackgroundColor [UIColor colorWithRedInt:200 greenInt:200 blueInt:206 alpha:1]
#define ISMSiPadCornerRadius 5.

#define ISMSBaseWidth 320.0
NS_INLINE CGFloat ISMSNormalize(CGFloat value)
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat percent = (screenWidth - ISMSBaseWidth) / screenWidth;
    CGFloat normalizedValue = value * (1 + percent);
    return normalizedValue;
}

#define ISMSSongCellHeight 44.0
#define ISMSAlbumCellHeight 50.0
#define ISMSArtistCellHeight 44.0

#endif
