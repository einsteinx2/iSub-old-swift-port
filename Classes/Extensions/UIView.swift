//
//  UIView.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit

extension UIView {
    var screenshot: UIImage {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.layer.isOpaque, 0.0)
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
