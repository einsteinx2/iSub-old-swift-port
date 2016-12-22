//
//  HelperFunctions.swift
//  iSub
//
//  Created by Benjamin Baron on 1/10/15.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

import Foundation

// MARK: - Play Songs -

private func _playAll(songs songs: [ISMSSong], shuffle: Bool, playIndex: Int) {
    // TODO: Implement
    fatalError("_playAll not implemented yet");
}

public func playAll(songs songs: [ISMSSong], playIndex: Int) {
    _playAll(songs: songs, shuffle: false, playIndex: playIndex)
}

public func shuffleAll(songs songs: [ISMSSong], playIndex: Int) {
    _playAll(songs: songs, shuffle: true, playIndex: playIndex)
}

// MARK: - Strings -

public func pluralizedString(count count: Int, singularNoun: String) -> String {
    var pluralizedString = "\(count) \(singularNoun)"
    if count != 1 {
        pluralizedString += "s"
    }
    
    return pluralizedString
}
