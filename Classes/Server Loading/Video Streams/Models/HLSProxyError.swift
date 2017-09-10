//
//  HLSProxyError.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//
// Loosely based on the example code here: https://github.com/kencool/KSHLSPlayer
//

import Foundation

enum HLSProxyError: Int, Error {
    case playlistUnavailable   = 1
    case playlistNotFound      = 2
    case accessDenied          = 3
}
