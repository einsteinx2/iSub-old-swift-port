//
//  StepperTableCell.swift
//  JGSettingsManager
//
//  Created by Jeff on 12/21/15.
//  Copyright © 2015 Jeff Greenberg. All rights reserved.
//

import UIKit

final class JGStepperTableCell: JGSettingsTableCell {
    
    //  MARK: UI
    
    fileprivate let stepper = UIStepper()
    fileprivate let label = UILabel()
    fileprivate let stackView = UIStackView()
    
    // MARK: Init
    
    init(data: JGUserDefault<Int>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, minimumValue: Int, maximumValue: Int) {
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
        initializeUI(minimumValue: minimumValue, maximumValue: maximumValue)
    }
    
    init(data: JGUserDefault<Double>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, minimumValue: Double, maximumValue: Double) {
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
        initializeUI(minimumValue: minimumValue, maximumValue: maximumValue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func setupViews() {
        super.setupViews()
        
        label.font = UIFont.monospacedDigitSystemFont(ofSize: controlFont.pointSize, weight: UIFont.Weight.medium)
        
        stepper.addTarget(self, action: #selector(save(_:)), for: .valueChanged)
        stackView.spacing = 12.0
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(stepper)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        controlContainer.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
     }
    
    fileprivate func initializeUI(minimumValue: Int, maximumValue: Int) {
        if let dataInt = dataInt {
            stepper.minimumValue = Double(minimumValue)
            stepper.maximumValue = Double(maximumValue)
            stepper.value = Double(dataInt.value())
            label.text = String(dataInt.value())
        }
     }
    
    fileprivate func initializeUI(minimumValue: Double, maximumValue: Double) {
        if let dataDouble = dataDouble {
            stepper.minimumValue = minimumValue
            stepper.maximumValue = maximumValue
            stepper.value = dataDouble.value()
            label.text = String(dataDouble.value())
        }
    }
    
    // MARK: Save
    
    @objc fileprivate func save(_ sender: UIStepper) {
        if let dataInt = dataInt {
            label.text = Int(sender.value).description
            dataInt.save(Int(sender.value))
        } else if let dataDouble = dataDouble {
            label.text = sender.value.description
            dataDouble.save(sender.value)
        }
    }
}
