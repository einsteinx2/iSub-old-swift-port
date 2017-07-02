//
//  JGSliderTableCell.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 7/2/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class JGSliderTableCell: JGSettingsTableCell {
    
    fileprivate let units: String?
    fileprivate let decimalPlaces: Int
    
    // MARK: UI
    
    fileprivate let valueLabel = UILabel()
    fileprivate let minLabel = UILabel()
    fileprivate let slider = UISlider()
    fileprivate let maxLabel = UILabel()
    
    // MARK: Init
    
    init(data: JGUserDefault<Float>, delegate: JGSettingsTableCellDelegate? = nil, title: String? = nil, subTitle: String? = nil, minimumValue: Float, maximumValue: Float, units: String? = nil, decimalPlaces: Int = 2, valueLabelWidth: CGFloat = 100) {
        self.units = units
        self.decimalPlaces = decimalPlaces
        super.init(data: data, delegate: delegate, title: title, subTitle: subTitle)
        initializeUI(minimumValue: minimumValue, maximumValue: maximumValue, valueLabelWidth: valueLabelWidth)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func setupViews() {
        super.setupViews()
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: controlFont.pointSize, weight: UIFont.Weight.medium)
        controlContainer.addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            
            // Must set a constant width or it will keep resizing as the text changes causing problems with the slider
            make.width.equalTo(100)
        }
        
        minLabel.translatesAutoresizingMaskIntoConstraints = false
        minLabel.font = controlFont
        minLabel.textAlignment = .right
        controlContainer.addSubview(minLabel)
        minLabel.snp.makeConstraints { make in
            make.leading.equalTo(valueLabel.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        maxLabel.font = controlFont
        maxLabel.textAlignment = .left
        controlContainer.addSubview(maxLabel)
        maxLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(valueChanged(_:)), for: .valueChanged)
        controlContainer.addSubview(slider)
        slider.snp.makeConstraints { make in
            make.leading.equalTo(minLabel.snp.trailing).offset(5)
            make.trailing.equalTo(maxLabel.snp.leading).offset(-5)
            make.centerY.equalToSuperview()
        }
    }
    
    fileprivate func initializeUI(minimumValue: Float, maximumValue: Float, valueLabelWidth: CGFloat) {
        if let dataFloat = dataFloat {
            slider.minimumValue = minimumValue
            slider.maximumValue = maximumValue
            slider.value = dataFloat.value()
            
            valueLabel.text = format(value: slider.value)
            valueLabel.snp.updateConstraints { make in
                make.width.equalTo(valueLabelWidth)
            }
            
            minLabel.text = format(value: minimumValue)
            maxLabel.text = format(value: maximumValue)
        }
    }
    
    @objc fileprivate func valueChanged(_ sender: UISlider) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(save(_:)), object: sender)
        self.perform(#selector(save(_:)), with: sender, afterDelay: 0.2)
        
        if sender.value < sender.minimumValue {
            sender.value = sender.minimumValue
        } else if sender.value > sender.maximumValue {
            sender.value = sender.maximumValue
        }
        
        valueLabel.text = format(value: slider.value)
    }
    
    fileprivate func format(value: Float) -> String {
        var formatted = String(format: "%.\(decimalPlaces)f", value)
        if let units = units {
            formatted += " \(units)"
        }
        return formatted
    }
    
    // MARK: Save
    
    @objc fileprivate func save(_ sender: UISlider) {
        dataFloat?.save(sender.value)
    }
}
