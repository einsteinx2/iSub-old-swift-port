//
//  SortOrder.swift
//  iSub
//
//  Created by Benjamin Baron on 3/19/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum SongSortOrder: Int {
    case track  = 0
    case title  = 1
    case artist = 2
    case album  = 3
}

enum ArtistSortOrder: Int {
    case name       = 0
    case albumCount = 1
}

enum AlbumSortOrder: Int {
    case year      = 0
    case name      = 1
    case artist    = 2
    case genre     = 3
    case songCount = 4
    case duration  = 5
}

