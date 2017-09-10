//
//  VideoLoader.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 9/9/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class VideoLoader: ApiLoader {
    let url: URL
    override var isDataApi: Bool { return true }
    
    init(url: URL, serverId: Int64 = SavedSettings.si.currentServerId) {
        self.url = url
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(url: url)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        log.error("Received non-error XML response loading URL: \(url)")
        return true
    }
}
