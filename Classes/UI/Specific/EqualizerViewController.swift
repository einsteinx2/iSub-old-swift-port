//
//  EqualizerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 3/26/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit

class EqualizerViewController: UIViewController, UIGestureRecognizerDelegate {
    fileprivate let sliderStackView = UIStackView()
    fileprivate var sliderContainerViews = [UIView]()
    fileprivate var sliderViews = [UISlider]()
    fileprivate var sliderLabels = [UILabel]()
    
    fileprivate var preampSlider = UISlider()
    fileprivate var enableButton = UIButton(type: .custom)
    
    fileprivate var values: [EqualizerValue] {
        return GaplessPlayer.si.equalizer.values
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
        
        sliderStackView.translatesAutoresizingMaskIntoConstraints = false
        sliderStackView.axis = .horizontal
        sliderStackView.alignment = .center
        sliderStackView.distribution = .equalSpacing
        self.view.addSubview(sliderStackView)
        sliderStackView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(self.view.snp.width)
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview()
        }
        
        createSliders()
        
        enableButton.addTarget(self, action: #selector(enableButtonAction(sender:)), for: .touchUpInside)
        self.view.addSubview(enableButton)
        enableButton.snp.makeConstraints { make in
            make.width.equalTo(100)
            make.height.equalTo(50)
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        updateEnableButtonTitle()
    }
    
    fileprivate func createSliders() {
        let values = self.values
        for value in values {
            let container = UIView()
            container.backgroundColor = .red
            container.translatesAutoresizingMaskIntoConstraints = false
            sliderStackView.addArrangedSubview(container)
            container.snp.makeConstraints { make in
                make.width.equalTo(30)
                make.height.equalToSuperview()
                make.top.equalToSuperview()
            }
            sliderContainerViews.append(container)

            let slider = UISlider()
            slider.addTarget(self, action: #selector(equalizerValueChanged(sender:)), for: .valueChanged)
            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.layer.anchorPoint = CGPoint.zero
            slider.transform = slider.transform.rotated(by: CGFloat(0.5 * Float.pi))
            slider.isContinuous = true
            slider.minimumValue = -15
            slider.maximumValue = 15
            slider.value = value.gain
            container.addSubview(slider)
            slider.snp.makeConstraints { make in
                make.width.equalTo(container.snp.height).offset(-50)
                make.height.equalTo(container.snp.width)
                make.left.equalTo(-152)
                make.top.equalTo(0)
            }
            sliderViews.append(slider)
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 12)
            label.text = value.frequency.label
            label.textAlignment = .center
            container.addSubview(label)
            label.snp.makeConstraints { make in
                make.width.equalToSuperview()
                make.height.equalTo(container.snp.width)
                make.left.equalToSuperview()
                make.bottom.equalToSuperview()
            }
            sliderLabels.append(label)
        }
        
        preampSlider.addTarget(self, action: #selector(preampValueChanged(sender:)), for: .valueChanged)
        preampSlider.minimumValue = 0.0
        preampSlider.maximumValue = 2.0
        preampSlider.value = 1.0
        self.view.addSubview(preampSlider)
        preampSlider.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-50)
            make.top.equalTo(sliderStackView.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
        }
    }
    
    fileprivate func updateEnableButtonTitle() {
        let title = GaplessPlayer.si.equalizer.isActive ? "Disable" : "Enable"
        enableButton.setTitle(title, for: .normal)
    }
    
    @objc fileprivate func enableButtonAction(sender: UIButton) {
        if GaplessPlayer.si.equalizer.isActive {
            GaplessPlayer.si.equalizer.disable()
        } else {
            GaplessPlayer.si.equalizer.enable()
        }
        
        updateEnableButtonTitle()
    }
    
    @objc fileprivate func equalizerValueChanged(sender: UISlider) {
        if let index = sliderViews.index(of: sender) {
            // NOTE: The value must be inverted because of the way the sliders are rotated
            GaplessPlayer.si.equalizer.updateValue(index: index, gain: -sender.value)
        }
    }
    
    @objc fileprivate func preampValueChanged(sender: UISlider) {
        GaplessPlayer.si.equalizer.updatePreampGain(gain: sender.value)
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: sliderStackView)
        return !sliderStackView.frame.contains(location)
    }
}
