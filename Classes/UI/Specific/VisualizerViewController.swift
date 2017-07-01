//
//  VisualizerViewController.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 7/1/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit

class VisualizerViewController: UIViewController, UIGestureRecognizerDelegate {
    fileprivate let visualizerView = VisualizerView()
    fileprivate let tapRecognizer = UITapGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .lightGray
        
        self.view.addSubview(visualizerView)
        visualizerView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(self.view.snp.width)
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview()
        }
        
        tapRecognizer.addTarget(self, action: #selector(handleTap(sender:)))
        visualizerView.addGestureRecognizer(tapRecognizer)
    }
    
    @objc fileprivate func handleTap(sender: UITapGestureRecognizer) {
        let reverse = sender.numberOfTouches > 1
        toggleVisualizer(reverse: reverse)
    }
    
    fileprivate func toggleVisualizer(reverse: Bool) {
        let type = visualizerView.visualizerType
        visualizerView.visualizerType = reverse ? type.previous : type.next
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
