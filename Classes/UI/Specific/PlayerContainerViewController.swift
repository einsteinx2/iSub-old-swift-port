//
//  PlayerContainerController.swift
//  iSub
//
//  Created by Benjamin Baron on 3/26/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import SnapKit

class PlayerContainerViewController: UIViewController, UIGestureRecognizerDelegate {
    let scrollView = UIScrollView()
    
    fileprivate let player = PlayerViewController()
    fileprivate let equalizer = EqualizerViewController()
    fileprivate let swipeRecognizer = UISwipeGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.bounces = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        self.view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalToSuperview()
            make.left.equalToSuperview()
        }
        
        player.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(player.view)
        player.view.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalToSuperview()
            make.left.equalToSuperview()
        }
        
        equalizer.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(equalizer.view)
        equalizer.view.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalToSuperview()
            make.left.equalTo(player.view.snp.right)
        }
        
        swipeRecognizer.direction = .down
        swipeRecognizer.addTarget(self, action: #selector(hidePlayer))
        swipeRecognizer.delegate = self
        scrollView.addGestureRecognizer(swipeRecognizer)
    }
    
    override func viewDidLayoutSubviews() {
        scrollView.contentSize = CGSize(width: self.view.bounds.width * 2, height: self.view.bounds.height)
    }
    
    @objc fileprivate func hidePlayer() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return scrollView.contentOffset.x == 0
    }
}
