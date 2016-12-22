//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

public func printError(_ error: Any, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = NSURL(fileURLWithPath: file).deletingPathExtension?.lastPathComponent
    let functionName = function.components(separatedBy: "(").first
    
    if let fileName = fileName, let functionName = functionName {
        print("[\(fileName):\(line) \(functionName)] \(error)")
    } else {
        print("[\(file):\(line) \(function)] \(error)")
    }
}

// Returns NSNull if the input is nil. Useful for things like db queries.
// TODO: Figure out why FMDB in Swift won't take nil arguments in var args functions
public func n2N(_ nullableObject: Any?) -> Any {
    return nullableObject == nil ? NSNull() : nullableObject!
}
