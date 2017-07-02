//
//  IntroViewController.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 7/2/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import AVKit

class IntroViewController: UIViewController {
    @IBOutlet weak var introVideo: UIButton!
    @IBOutlet weak var testServer: UIButton!
    @IBOutlet weak var ownServer: UIButton!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    @IBAction func buttonPress(_ sender: UIButton) {
        if sender == introVideo {
            let introUrl: URL?
            if UIScreen.main.scale > 1.0 {
                introUrl = URL(string: "http://isubapp.com/intro/iphone4/prog_index.m3u8")
            } else {
                introUrl = URL(string: "http://isubapp.com/intro/iphone/prog_index.m3u8")
            }
            
            if let introUrl = introUrl {
                let playerViewController = AVPlayerViewController()
                playerViewController.player = AVPlayer(url: introUrl)
                self.present(playerViewController, animated: true) {
                    playerViewController.player?.play()
                }
            }
        } else if sender == testServer {
            self.dismiss(animated: true, completion: nil)
        } else if sender == ownServer {
            self.dismiss(animated: true, completion: nil)
            if let menu = AppDelegate.si.sidePanelController.leftPanel as? MenuViewController {
                menu.showSettings()
            }
        }
    }
}
