//
//  SidePanelController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class SidePanelController: JASidePanelController {

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let menu = NewMenuViewController()
        self.leftPanel = menu
        self.rightPanel = PlayQueueViewController()
        menu.showDefaultViewController()
    }
}
