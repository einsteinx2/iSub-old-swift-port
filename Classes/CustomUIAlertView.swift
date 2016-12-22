//
//  CustomUIAlertView.m
//  iSub
//
//  Created by Ben Baron on 2/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

import UIKit

open class CustomUIAlertView : UIAlertView {
    
    open override func show() {
        if SavedSettings.sharedInstance().isPopupsEnabled {
            super.show()
        }
    }
}
