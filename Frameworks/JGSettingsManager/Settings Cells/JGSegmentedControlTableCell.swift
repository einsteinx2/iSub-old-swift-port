//
//  SegmentedControlTableCell.swift
//  JGSettingsManager
//
//  Created by Jeff on 12/22/15.
//  Copyright © 2015 Jeff Greenberg. All rights reserved.
//

import UIKit

final class JGSegmentedControlTableCell: JGSettingsTableCell {
    
    //  MARK: UI
    
    fileprivate let segmentedControl = UISegmentedControl()
    
    // MARK: Init
    
    init(data: JGUserDefault<Int>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, segments: [String]) {
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
        initializeUI(segments: segments)
    }
    
    init(data: JGUserDefault<String>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, segments: [String]) {
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func setupViews() {
        super.setupViews()
        
        segmentedControl.setFontSize(controlFont.pointSize)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(save(_:)), for: .valueChanged)
        controlContainer.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    fileprivate func initializeUI(segments: [String]) {
        if let dataInt = dataInt {
            for (index, segment) in segments.enumerated() {
                segmentedControl.insertSegment(withTitle: segment, at: index, animated: false)
            }
            
            segmentedControl.selectedSegmentIndex = dataInt.value()
        } else if let dataString = dataString {
            var selectedSegmentIndex = 0
            let stringValue = dataString.value()
            
            for (index, segment) in segments.enumerated() {
                if segment == stringValue { selectedSegmentIndex = index }
                segmentedControl.insertSegment(withTitle: segment, at: index, animated: false)
            }
            
            // set the default to zero to avoid error
            // it is initiailied to -1 by iOS
            segmentedControl.selectedSegmentIndex = selectedSegmentIndex
        }
    }
    
    // MARK: Save

    @objc fileprivate func save(_ sender: UISegmentedControl) {
        if let dataInt = dataInt {
            dataInt.save(sender.selectedSegmentIndex)
        } else if let dataString = dataString, let title = sender.titleForSegment(at: sender.selectedSegmentIndex) {
            dataString.save(title)
        }
    }
}

extension UISegmentedControl {
    func setFontSize(_ fontSize: CGFloat) {
        let normalTextAttributes: [AnyHashable: Any] = [
            NSAttributedStringKey.foregroundColor: UIColor.black,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight.regular)
        ]
        
        let boldTextAttributes: [AnyHashable: Any] = [
            NSAttributedStringKey.foregroundColor : UIColor.white,
            NSAttributedStringKey.font : UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight.medium)
        ]
        
        self.setTitleTextAttributes(normalTextAttributes, for: UIControlState())
        self.setTitleTextAttributes(normalTextAttributes, for: .highlighted)
        self.setTitleTextAttributes(boldTextAttributes, for: .selected)
    }
}
