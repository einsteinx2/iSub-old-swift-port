//
//  TextTableCell.swift
//  JGSettingsManager
//
//  Created by Jeff on 12/21/15.
//  Copyright © 2015 Jeff Greenberg. All rights reserved.
//

import UIKit

final class JGTextTableCell: JGSettingsTableCell, UITextFieldDelegate {
    
    // MARK: Data
    
    fileprivate var data: JGUserDefault<String>!
    
    //  MARK: UI
    
    fileprivate let textField = UITextField()
    
    // MARK: Init
    
    init(data: JGUserDefault<String>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, placeholder: String) {
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
        
        initializeUI(placeholder: placeholder)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func setupViews() {
        super.setupViews()
        
        textField.delegate = self
        addSubview(textField)
        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    
    fileprivate func initializeUI(placeholder: String) {
        textField.placeholder = placeholder
        textField.text = data.value()
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        save()
        return false
    }
    
    // MARK: Save
    
    public func save() {
        data.save(textField.text ?? "")
    }
}

