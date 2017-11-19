//
//  ContentType.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

enum BasicContentType: Int64 {
    case audio = 1
    case video = 2
    case image = 3
}

final class ContentType {
    let contentTypeId: Int64
    let mimeType: String
    let fileExtension: String
    let basicTypeId: Int64
    
    let basicType: BasicContentType?
    
    init(contentTypeId: Int64, mimeType: String, fileExtension: String, basicTypeId: Int64) {
        self.contentTypeId = contentTypeId
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.basicTypeId = basicTypeId
        
        self.basicType = BasicContentType(rawValue: basicTypeId)
    }
}
