//
//  JGSettingsTableCell.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 7/1/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc protocol JGSettingsTableCellDelegate {
    @objc optional func settingsTableCellTitleFont(_ cell: JGSettingsTableCell) -> UIFont
    @objc optional func settingsTableCellTitleColor(_ cell: JGSettingsTableCell) -> UIColor
    @objc optional func settingsTableCellSubTitleFont(_ cell: JGSettingsTableCell) -> UIFont
    @objc optional func settingsTableCellSubTitleColor(_ cell: JGSettingsTableCell) -> UIColor
    @objc optional func settingsTableCellLabelFont(_ cell: JGSettingsTableCell) -> UIFont
    @objc optional func settingsTableCellControlFont(_ cell: JGSettingsTableCell) -> UIFont
}

open class JGSettingsTableCell: UITableViewCell {
    
    //  MARK: UI
    
    let titleLabel = UILabel()
    let subTitleLabel = UILabel()
    let controlContainer = UIView()
    
    fileprivate var titleHeight: CGFloat {
        let width = UIScreen.main.bounds.size.width
        if let title = title {
            return title.size(font: titleLabel.font, targetSize: CGSize(width: width, height: 44)).height + 5
        }
        return 0
    }
    
    fileprivate var subTitleHeight: CGFloat {
        let width = UIScreen.main.bounds.size.width
        if let subTitle = subTitle {
            // TODO: Why is the height calculation so far off?
            return subTitle.size(font: subTitleLabel.font, targetSize: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height + 20
        }
        return 0
    }
    
    var cellHeight: CGFloat {
        return titleHeight + subTitleHeight + 44 + 5
    }
    
    // MARK: UI Customization
    
    weak var delegate: JGSettingsTableCellDelegate?
    
    var titleFont: UIFont { return delegate?.settingsTableCellTitleFont?(self) ?? UIFont.systemFont(ofSize: 17) }
    var titleColor: UIColor { return delegate?.settingsTableCellTitleColor?(self) ?? .black }
    var subTitleFont: UIFont { return delegate?.settingsTableCellSubTitleFont?(self) ?? UIFont.systemFont(ofSize: 13) }
    var subTitleColor: UIColor { return delegate?.settingsTableCellTitleColor?(self) ?? .gray }
    var labelFont: UIFont { return delegate?.settingsTableCellLabelFont?(self) ?? UIFont.systemFont(ofSize: 17) }
    var controlFont: UIFont { return delegate?.settingsTableCellControlFont?(self) ?? UIFont.systemFont(ofSize: 17) }
    
    // MARK: Data
    
    fileprivate var data: Any?
    var dataInt: JGUserDefault<Int>? { return data as? JGUserDefault<Int> }
    var dataFloat: JGUserDefault<Float>? { return data as? JGUserDefault<Float> }
    var dataDouble: JGUserDefault<Double>? { return data as? JGUserDefault<Double> }
    var dataBool: JGUserDefault<Bool>? { return data as? JGUserDefault<Bool> }
    var dataString: JGUserDefault<String>? { return data as? JGUserDefault<String> }
    
    var title: String?
    var subTitle: String?
    
    // MARK: Init
    
    init<T>(data: JGUserDefault<T>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil) {
        super.init(style: .`default`, reuseIdentifier: nil)
        
        self.data = data
        self.delegate = delegate
        self.title = title
        self.subTitle = subTitle
        
        setupViews()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    func setupViews() {
        titleLabel.text = title
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        titleLabel.numberOfLines = 1
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.height.equalTo(titleHeight)
        }
        
        subTitleLabel.text = subTitle
        subTitleLabel.font = subTitleFont
        subTitleLabel.textColor = subTitleColor
        subTitleLabel.numberOfLines = 0
        contentView.addSubview(subTitleLabel)
        subTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.height.equalTo(subTitleHeight)
        }
        
        contentView.addSubview(controlContainer)
        controlContainer.snp.makeConstraints { make in
            make.top.equalTo(subTitleLabel.snp.bottom)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(44)
        }
    }
}
