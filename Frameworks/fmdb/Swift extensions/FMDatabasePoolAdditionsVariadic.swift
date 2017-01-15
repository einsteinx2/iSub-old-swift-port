//
//  FMDatabasePoolAdditionsVariadic.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension FMDatabasePool {
    func stringForQuery(_ sql: String, _ values: Any...) -> String? {
        var value: String?
        self.inDatabase { db in
            value = db.stringForQuery(sql, values)
        }
        return value
    }
    
    func intOptionalForQuery(_ sql: String, _ values: Any...) -> Int32? {
        var value: Int32?
        self.inDatabase { db in
            value = db.intOptionalForQuery(sql, values)
        }
        return value
    }
    
    func intForQuery(_ sql: String, _ values: Any...) -> Int32 {
        var value: Int32 = 0
        self.inDatabase { db in
            value = db.intForQuery(sql, values)
        }
        return value
    }
    
    func longOptionalForQuery(_ sql: String, _ values: Any...) -> Int? {
        var value: Int?
        self.inDatabase { db in
            value = db.longOptionalForQuery(sql, values)
        }
        return value
    }
    
    func longForQuery(_ sql: String, _ values: Any...) -> Int {
        var value: Int = 0
        self.inDatabase { db in
            value = db.longForQuery(sql, values)
        }
        return value
    }
    
    func boolOptionalForQuery(_ sql: String, _ values: Any...) -> Bool? {
        var value: Bool?
        self.inDatabase { db in
            value = db.boolOptionalForQuery(sql, values)
        }
        return value
    }
    
    func boolForQuery(_ sql: String, _ values: Any...) -> Bool {
        var value: Bool = false
        self.inDatabase { db in
            value = db.boolForQuery(sql, values)
        }
        return value
    }
    
    func doubleOptionalForQuery(_ sql: String, _ values: Any...) -> Double? {
        var value: Double?
        self.inDatabase { db in
            value = db.doubleOptionalForQuery(sql, values)
        }
        return value
    }
    
    func doubleForQuery(_ sql: String, _ values: Any...) -> Double {
        var value: Double = 0
        self.inDatabase { db in
            value = db.doubleForQuery(sql, values)
        }
        return value
    }
    
    func dateForQuery(_ sql: String, _ values: Any...) -> Date? {
        var value: Date?
        self.inDatabase { db in
            value = db.dateForQuery(sql, values)
        }
        return value
    }
    
    func dataForQuery(_ sql: String, _ values: Any...) -> Data? {
        var value: Data?
        self.inDatabase { db in
            value = db.dataForQuery(sql, values)
        }
        return value
    }
}
