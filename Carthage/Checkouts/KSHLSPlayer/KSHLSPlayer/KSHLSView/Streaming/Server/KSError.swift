//
//  KSError.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/22.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public struct KSError {
    
    public static let Domain = "ks.stream.error"
    
    public enum Code: Int {
        case PlaylistUnchanged      = -1
        case PlaylistUnavailable    = -2
        case PlaylistNotFound       = -3
        case PlaylistIsEmpty        = -4
        case AuthenticationFailed   = -5
        case InvaildUrl             = -6
        case AccessDenied           = -7
    }
    
    public let code: Code
    
    public let nsError: NSError?
    
    public init(code: Code) {
        self.init(code: code, nsError: nil)
    }
    
    public init(code: Code, failureReason: String) {
        let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
        self.init(code: code, nsError: NSError(domain: KSError.Domain, code: code.rawValue, userInfo: userInfo))
    }
    
    public init(code: Code, nsError: NSError?) {
        self.code = code
        self.nsError = nsError
    }
}