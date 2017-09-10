//
//  HLSSelfSignedCertDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//

import Foundation

class SelfSignedCertDelegate: NSObject, URLSessionTaskDelegate {
    static let shared = SelfSignedCertDelegate()
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential())
        }
    }
}
