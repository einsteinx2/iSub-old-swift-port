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

class ContentType {
    let contentTypeId: Int64
    let mimeType: String
    let fileExtension: String
    let basicTypeId: Int64
    
    let basicType: BasicContentType?
    
    init(result: FMResultSet) {
        self.contentTypeId = result.longLongInt(forColumnIndex: 0)
        self.mimeType = result.string(forColumnIndex: 1) ?? ""
        self.fileExtension = result.string(forColumnIndex: 2) ?? ""
        self.basicTypeId = result.longLongInt(forColumnIndex: 3)
        self.basicType = BasicContentType(rawValue: self.basicTypeId)
    }
}

class ContentTypeRepository {
    static let si = ContentTypeRepository()
    
    func contentType(contentTypeId: Int64) -> ContentType? {
        var contentType: ContentType? = nil
        Database.si.read.inDatabase { db in
            let query = "SELECT * FROM contentTypes WHERE contentTypeId = ?"
            do {
                let result = try db.executeQuery(query, contentTypeId)
                if result.next() {
                    contentType = ContentType(result: result)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return contentType
    }
    
    func contentType(mimeType: String) -> ContentType? {
        var contentType: ContentType? = nil
        Database.si.read.inDatabase { db in
            let query = "SELECT * FROM contentTypes WHERE mimeType = ?"
            do {
                let result = try db.executeQuery(query, mimeType)
                if result.next() {
                    contentType = ContentType(result: result)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return contentType
    }
}
