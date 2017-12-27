//
//  NSError.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

let SubsonicErrorDomain = "SubsonicErrorDomain"
let iSubErrorDomain = "iSubErrorDomain"
enum iSubErrorCode: Int {
    case notSubsonicServer = 1
    case notXML = 2
    case couldNotCreateConnection = 3
    case invalidCredentials = 4
    case couldNotReachServer = 5
    case subsonicTrialExpired = 6
    case requiresBasicAuth = 7
    case serverNotInDb = 8
    case tokenAuthNotSupported = 9
    
    var description: String {
        switch self {
        case .notSubsonicServer: return "This is not a Subsonic server"
        case .notXML: return "This is not valid XML data"
        case .couldNotCreateConnection: return "Could not create network connection"
        case .invalidCredentials: return "Incorrect username or password"
        case .couldNotReachServer: return "Could not reach the server"
        case .subsonicTrialExpired: return "Subsonic API Trial Expired"
        case .requiresBasicAuth: return "Requires HTTP Basic Authentication"
        case .serverNotInDb: return "The server does not exist in the database"
        case .tokenAuthNotSupported: return "Server does not support token authentication"
        }
    }
}

extension NSError {
    convenience init(iSubCode: iSubErrorCode) {
        let userInfo = [NSLocalizedDescriptionKey: iSubCode.description]
        self.init(domain: iSubErrorDomain, code: iSubCode.rawValue, userInfo: userInfo)
    }
}
