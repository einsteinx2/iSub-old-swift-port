//
//  SwitchTableCell.swift
//  JGSettingsManager
//
//  Created by Jeff on 12/13/15.
//  Copyright © 2015 Jeff Greenberg. All rights reserved.
//

import UIKit

final class JGSwitchTableCell: JGSettingsTableCell {
    
    // MARK: UI
    
    fileprivate let boolSwitch = UISwitch()
    fileprivate let label = UILabel()
    
    // MARK: Init
    
    init(data: JGUserDefault<Bool>,  delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, labelString: String) {
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
        initializeUI(labelString: labelString, on: data.value())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func setupViews() {
        super.setupViews()
        
        controlContainer.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
        
        boolSwitch.addTarget(self, action: #selector(save(_:)), for: .valueChanged)
        controlContainer.addSubview(boolSwitch)
        boolSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
    }
    
    fileprivate func initializeUI(labelString: String, on: Bool) {
        label.text = labelString
        boolSwitch.setOn(on, animated: false)
    }
    
    // MARK: Save
    
    @objc fileprivate func save(_ sender: UISwitch) {
        dataBool?.save(sender.isOn)
    }
}
