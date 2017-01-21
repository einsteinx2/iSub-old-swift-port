//
//  CenterPanelContainerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 6/17/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

class CenterPanelContainerViewController: UIViewController {
    
    fileprivate let contentView = UIView()
    fileprivate let miniPlayer = MiniPlayerViewController()
    fileprivate let miniPlayerHeight = 64
    fileprivate var miniPlayerShowing = false
    
    var contentController: UIViewController? {
        willSet {
            swapContentControllers(oldController: contentController, newController: newValue)
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func loadView() {
        self.view = UIView()
        
        miniPlayerShowing = (PlayQueue.si.currentSong != nil)
        
        self.view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        self.addChildViewController(miniPlayer)
        self.view.addSubview(miniPlayer.view)
        miniPlayer.view.snp.makeConstraints { make in
            make.height.equalTo(miniPlayerHeight)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(miniPlayerShowing ? 0: miniPlayerHeight)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(indexChanged), name: PlayQueue.Notifications.indexChanged)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self, name: PlayQueue.Notifications.indexChanged)
    }
    
    @objc fileprivate func indexChanged() {
        if PlayQueue.si.currentSong != nil {
            showMiniPlayer(animated: true)
        } else {
            hideMiniPlayer(animated: true)
        }
    }
    
    fileprivate func swapContentControllers(oldController: UIViewController?, newController: UIViewController?) {
        if (oldController != newController) {
            if let oldController = oldController {
                oldController.willMove(toParentViewController: nil)
                oldController.view.removeFromSuperview()
                oldController.removeFromParentViewController()
            }
            
            if let newController = newController {
                self.addChildViewController(newController)
                contentView.addSubview(newController.view)
                newController.view.snp.makeConstraints { make in
                    make.top.equalTo(contentView)
                    make.bottom.equalTo(contentView)
                    make.left.equalTo(contentView)
                    make.right.equalTo(contentView)
                }
                newController.didMove(toParentViewController: self)
            }
        }
    }
    
    func showMiniPlayer(animated: Bool) {
        if !miniPlayerShowing {
            miniPlayerShowing = true
            updateMiniPlayerBottomConstraint(offset: 0, animated: true)
        }
    }
    
    func hideMiniPlayer(animated: Bool) {
        if miniPlayerShowing {
            miniPlayerShowing = false
            updateMiniPlayerBottomConstraint(offset: miniPlayerHeight, animated: true)
        }
    }
    
    fileprivate func updateMiniPlayerBottomConstraint(offset: Int, animated: Bool) {
        miniPlayer.view.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(offset)
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
    
}
