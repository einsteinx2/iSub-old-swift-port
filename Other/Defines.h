//
//  Defines.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Defines_h
#define iSub_Defines_h

#import "ISMSNotificationNames.h"
#import "ISMSErrorDomain.h"
#import "SUSErrorDomain.h"

#define ISMSLoadingTimeout 240.0
#define ISMSJukeboxTimeout 60.0
#define ISMSServerCheckTimeout 15.0

#define ISMSiPadBackgroundColor [UIColor colorWithPatternImage:[UIImage imageNamed:@"underPageBackground.png"]]
#define ISMSiPadCornerRadius 5.

typedef enum
{
    ISMSBassVisualType_none      = 0,
    ISMSBassVisualType_line      = 1,
    ISMSBassVisualType_skinnyBar = 2,
    ISMSBassVisualType_fatBar    = 3,
    ISMSBassVisualType_aphexFace = 4,
    ISMSBassVisualType_maxValue  = 5
} ISMSBassVisualType;

#endif
