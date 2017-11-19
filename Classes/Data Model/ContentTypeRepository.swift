//
//  ContentTypeRepository.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 11/19/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct ContentTypeRepository {
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

extension ContentType {
    convenience init(result: FMResultSet) {
        let contentTypeId = result.longLongInt(forColumnIndex: 0)
        let mimeType = result.string(forColumnIndex: 1) ?? ""
        let fileExtension = result.string(forColumnIndex: 2) ?? ""
        let basicTypeId = result.longLongInt(forColumnIndex: 3)
        
        self.init(contentTypeId: contentTypeId, mimeType: mimeType, fileExtension: fileExtension, basicTypeId: basicTypeId)
    }
}
