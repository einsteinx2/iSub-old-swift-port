//
//  CustomUIAlertView.m
//  iSub
//
//  Created by Ben Baron on 2/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

import libSub
import UIKit

public class CustomUIAlertView : UIAlertView {
    
    public override func show() {
        if SavedSettings.sharedInstance().isPopupsEnabled {
            super.show()
        }
    }
}