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
    fileprivate var miniPlayerShowing = true
    
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
        
        let hideMiniPlayer = (PlayQueue.sharedInstance.currentSong == nil)
        
        self.view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(hideMiniPlayer ? 0 : -50)
        }
        
        self.view.addSubview(miniPlayer.view)
        miniPlayer.view.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(hideMiniPlayer ? 50 : 0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(CenterPanelContainerViewController.indexChanged), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
    }
    
    @objc fileprivate func indexChanged() {
        if PlayQueue.sharedInstance.currentSong != nil {
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
                    make.width.equalTo(contentView)
                    make.height.equalTo(contentView)
                    make.leading.equalTo(contentView)
                    make.trailing.equalTo(contentView)
                }
                newController.didMove(toParentViewController: self)
            }
        }
    }
    
    func showMiniPlayer(animated: Bool) {
        if !miniPlayerShowing {
            miniPlayerShowing = true
            updateConstraintOffsets(contentViewOffset: -50, miniPlayerOffset: 0, animated: true)
        }
    }
    
    func hideMiniPlayer(animated: Bool) {
        if miniPlayerShowing {
            miniPlayerShowing = false
            updateConstraintOffsets(contentViewOffset: 0, miniPlayerOffset: 50, animated: true)
        }
    }
    
    fileprivate func updateConstraintOffsets(contentViewOffset: Float, miniPlayerOffset: Float, animated: Bool) {
        contentView.snp.updateConstraints { make in make.bottom.equalToSuperview().offset(contentViewOffset) }
        contentView.setNeedsLayout()
        
        miniPlayer.view.snp.updateConstraints { make in make.bottom.equalToSuperview().offset(miniPlayerOffset) }
        miniPlayer.view.setNeedsLayout()
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                self.contentView.layoutIfNeeded()
                self.miniPlayer.view.layoutIfNeeded()
            }, completion: nil)
        } else {
            contentView.layoutIfNeeded()
            miniPlayer.view.layoutIfNeeded()
        }
    }
    
    
}
