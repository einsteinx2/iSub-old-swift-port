//
//  Application.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class Application: UIApplication {
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override init() {
        super.init()
        self.becomeFirstResponder()
        self.beginReceivingRemoteControlEvents()
    }
    
    // TODO: Audit all this and test
    override func remoteControlReceived(with event: UIEvent?) {
        if let event = event {
            switch event.subtype {
            case .remoteControlPlay, .remoteControlPause, .remoteControlStop, .remoteControlTogglePlayPause:
                if PlayQueue.si.isStarted {
                    PlayQueue.si.playPause()
                } else {
                    PlayQueue.si.playSong(atIndex: PlayQueue.si.currentIndex)
                }
            case .remoteControlNextTrack:
                PlayQueue.si.playNextSong()
            case .remoteControlPreviousTrack:
                PlayQueue.si.playPreviousSong()
            default:
                break
            }
        }
    }
}
