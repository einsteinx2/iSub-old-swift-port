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
        if let value = self.attribute(attributeName), value.characters.count > 0 {
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
}
