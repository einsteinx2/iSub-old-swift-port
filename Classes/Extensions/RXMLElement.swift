//
//  RXMLElement.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension RXMLElement {
    func attribute(asStringOptional attributeName: String) -> String? {
        if let value = self.attribute(attributeName), value.count > 0 {
            return value
        }
        return nil
    }
    
    func attribute(asIntOptional attributeName: String) -> Int? {
        if let stringValue = self.attribute(attributeName), let value = Int(stringValue) {
            return value
        }
        return nil
    }
    
    func attribute(asInt64Optional attributeName: String) -> Int64? {
        if let stringValue = self.attribute(attributeName), let value = Int64(stringValue) {
            return value
        }
        return nil
    }
    
    func attribute(asInt64 attributeName: String) -> Int64 {
        return attribute(asInt64Optional: attributeName) ?? Int64(0)
    }
}
