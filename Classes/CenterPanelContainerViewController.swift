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
    
    private let contentView = UIView()
    private let miniPlayer = MiniPlayerViewController()
    private var miniPlayerShowing = true
    
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
        
        self.view.addSubview(contentView)
        contentView.snp_makeConstraints { make in
            make.width.equalTo(self.view)
            make.top.equalTo(self.view)
            make.bottom.equalTo(self.view).offset(-50)
        }
        
        self.view.addSubview(miniPlayer.view)
        miniPlayer.view.snp_makeConstraints { make in
            make.height.equalTo(50)
            make.width.equalTo(self.view)
            make.bottom.equalTo(self.view).offset(0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if PlayQueue.sharedInstance.currentSong == nil {
            hideMiniPlayer(animated: false)
        }
        
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(CenterPanelContainerViewController.indexChanged), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    deinit {
        NSNotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    @objc private func indexChanged() {
        if PlayQueue.sharedInstance.currentSong != nil {
            showMiniPlayer(animated: true)
        } else {
            hideMiniPlayer(animated: true)
        }
    }
    
    private func swapContentControllers(oldController oldController: UIViewController?, newController: UIViewController?) {
        if (oldController != newController) {
            if let oldController = oldController {
                oldController.willMoveToParentViewController(nil)
                oldController.view.removeFromSuperview()
                oldController.removeFromParentViewController()
            }
            
            if let newController = newController {
                self.addChildViewController(newController)
                contentView.addSubview(newController.view)
                newController.view.snp_makeConstraints { make in
                    make.width.equalTo(contentView)
                    make.height.equalTo(contentView)
                    make.leading.equalTo(contentView)
                    make.trailing.equalTo(contentView)
                }
                newController.didMoveToParentViewController(self)
            }
        }
    }
    
    func showMiniPlayer(animated animated: Bool) {
        if !miniPlayerShowing {
            miniPlayerShowing = true
            updateConstraintOffsets(contentViewOffset: -50, miniPlayerOffset: 0, animated: true)
        }
    }
    
    func hideMiniPlayer(animated animated: Bool) {
        if miniPlayerShowing {
            miniPlayerShowing = false
            updateConstraintOffsets(contentViewOffset: 0, miniPlayerOffset: 50, animated: true)
        }
    }
    
    private func updateConstraintOffsets(contentViewOffset contentViewOffset: Float, miniPlayerOffset: Float, animated: Bool) {
        contentView.snp_updateConstraints { make in make.bottom.equalTo(self.view).offset(contentViewOffset) }
        contentView.setNeedsLayout()
        
        miniPlayer.view.snp_updateConstraints { make in make.bottom.equalTo(self.view).offset(miniPlayerOffset) }
        miniPlayer.view.setNeedsLayout()
        
        if animated {
            UIView.animateWithDuration(0.25, delay: 0, options: .CurveEaseIn, animations: {
                self.contentView.layoutIfNeeded()
                self.miniPlayer.view.layoutIfNeeded()
            }, completion: nil)
        } else {
            contentView.layoutIfNeeded()
            miniPlayer.view.layoutIfNeeded()
        }
    }
    
    
}
