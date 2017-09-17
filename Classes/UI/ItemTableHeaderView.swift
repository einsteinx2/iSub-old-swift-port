//
//  ItemTableHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 3/19/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import SnapKit

class ItemTableHeaderView: UIView {
    let width: CGFloat
    var height: CGFloat { return coverArtId == nil ? labelContainerHeight : width }
    let titleLabelHeight: CGFloat = 30
    let subTitleLabelHeight: CGFloat = 20
    let labelContainerHeight: CGFloat = 100
    fileprivate var gradientHeight: CGFloat {
        return labelContainerHeight + 130
    }
    
    var associatedItem: Item?
    
    var coverArtId: String? {
        didSet {
            if let coverArtId = coverArtId, let serverId = associatedItem?.serverId {
                coverArtView.loadImage(coverArtId: coverArtId, serverId: serverId, size: .player)
            } else {
                coverArtView.setDefaultImage(forSize: .player)
            }
            
            self.snp.makeConstraints { make in
                make.height.equalTo(height)
            }
        }
    }
    
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    
    var subTitle: String? {
        didSet {
            subTitleLabel.text = subTitle
        }
    }

    fileprivate let coverArtView = CachedImageView()
    fileprivate let gradientView = UIView()
    fileprivate let labelContainer = UIView()
    fileprivate let gradientLayer = CAGradientLayer()
    fileprivate let titleLabel = UILabel()
    fileprivate let subTitleLabel = UILabel()
    
    // MARK: - Lifecycle -
    
    convenience init(width: CGFloat) {
        self.init(frame: CGRect(x: 0, y: 0, width: width, height: width))
        commonInit()
    }
    
    override init(frame: CGRect) {
        self.width = frame.size.width
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    fileprivate func commonInit() {
        self.backgroundColor = .white
        
        self.addSubview(coverArtView)
        
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        gradientLayer.locations = [0.0, 1.3]
        gradientView.layer.addSublayer(gradientLayer)
        gradientView.backgroundColor = .clear
        self.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(gradientHeight)
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        self.addSubview(labelContainer)
        labelContainer.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(labelContainerHeight)
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        titleLabel.backgroundColor = .clear
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = UIFont.systemFont(ofSize: 24)
        labelContainer.addSubview(titleLabel)
        
        subTitleLabel.backgroundColor = .clear
        subTitleLabel.textColor = .white
        subTitleLabel.textAlignment = .left
        subTitleLabel.lineBreakMode = .byTruncatingTail
        subTitleLabel.font = UIFont.systemFont(ofSize: 18)
        labelContainer.addSubview(subTitleLabel)
    }
    
    override func didMoveToWindow() {
        if let superview = self.superview {
            let width = superview.frame.size.width
            gradientLayer.frame = CGRect(x: 0, y: 0, width: width, height: gradientHeight)
            if coverArtId == nil {
                self.frame = CGRect(x: 0, y: 0, width: width, height: labelContainerHeight)
                coverArtView.isHidden = true
            } else {
                self.frame = CGRect(x: 0, y: 0, width: width, height: width)
                coverArtView.frame = self.bounds
                coverArtView.isHidden = false
            }

            let labelOffset: CGFloat = 10
            if subTitle == nil {
                titleLabel.frame = CGRect(x: labelOffset,
                                          y: labelContainerHeight - titleLabelHeight - labelOffset,
                                          width: width - (labelOffset * 2),
                                          height: titleLabelHeight)
            } else {
                titleLabel.frame = CGRect(x: labelOffset,
                                          y: labelContainerHeight - titleLabelHeight - subTitleLabelHeight - (labelOffset * 2),
                                          width: width - (labelOffset * 2),
                                          height: titleLabelHeight)
                subTitleLabel.frame = CGRect(x: labelOffset,
                                          y: labelContainerHeight - subTitleLabelHeight - labelOffset,
                                          width: width - (labelOffset * 2),
                                          height: subTitleLabelHeight)
            }
        }
    }
}
