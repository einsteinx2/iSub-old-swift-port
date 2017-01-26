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
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    func scaledFrame(x: CGFloat, y: CGFloat) -> CGRect {
        var scaledFrame = self.frame
        scaledFrame.size.width *= x
        scaledFrame.size.height *= y
        scaledFrame.origin.x = self.frame.origin.x - (((self.frame.size.width * x) - self.frame.size.width) / 2)
        scaledFrame.origin.y = self.frame.origin.y - (((self.frame.size.height * y) - self.frame.size.height) / 2)
        return scaledFrame
    }
}
