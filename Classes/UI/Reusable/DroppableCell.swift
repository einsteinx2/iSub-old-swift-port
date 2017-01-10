//
//  DroppableCell.swift
//  iSub
//
//  Created by Benjamin Baron on 5/19/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

// Cell that expands to allow dropping underneath it
class DroppableCell: UITableViewCell {
    
    let containerView = UIView()
    var cellHeight: CGFloat = 50.0 {
        didSet {
            containerView.snp.updateConstraints { make in
                make.height.equalTo(cellHeight)
            }
        }
    }
    
    var tableView: UITableView? {
        var view = self.superview
        while view != nil {
            if let tableView = view as? UITableView {
                return tableView
            }
            view = view?.superview
        }
        return nil
    }
    
    override var backgroundColor: UIColor? {
        get {
            return containerView.backgroundColor
        }
        set {
            containerView.backgroundColor = newValue
        }
    }
    
    fileprivate func commonInit() {
        super.backgroundColor = .clear
        
        containerView.backgroundColor = .white
        self.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(self)
            make.height.equalTo(cellHeight)
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
}
