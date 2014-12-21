//
//  SUSURLConnection.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation

@objc public class SUSURLConnection: NSObject, NSURLConnectionDataDelegate {
    
    public let action: String
    public let parameters: Dictionary<String, String>?
    public let userInfo: Dictionary<String, AnyObject>?
    
    private let _request: NSMutableURLRequest
    private let _connection: NSURLConnection?
    private let _receivedData: NSMutableData?
    
    private let _receivedDataHandler: ((data: NSData) -> ())?
    private let _successHandler: (data: NSData?, userInfo: Dictionary<String, AnyObject>?) -> ()
    private let _failureHandler: (error: NSError) -> ()
    
    public init(action: String, parameters: Dictionary<String, String>?, userInfo: Dictionary<String, AnyObject>?, receivedData: ((data: NSData) -> ())?, success:(data: NSData?, userInfo: Dictionary<String, AnyObject>?) -> (), failure:(error: NSError) -> ())
    {
        self.action = action
        self.parameters = parameters
        self.userInfo = userInfo
        
        self._receivedDataHandler = receivedData
        self._successHandler = success
        self._failureHandler = failure
        
        self._request = NSMutableURLRequest(SUSAction: action, parameters: parameters)
        
        super.init()
        
        if let connection = NSURLConnection(request: self._request, delegate: self) {
            self._connection = connection
            
            if self._receivedDataHandler == nil {
                self._receivedData = NSMutableData()
            }
            
            self._connection?.start()
        } else {
            let code: Int = Int(ISMSErrorCode_CouldNotCreateConnection)
            self._failureHandler(error: NSError(ISMSCode: code))
        }
    }
    
    public convenience init(action: String, parameters: Dictionary<String, String>?, userInfo: Dictionary<String, AnyObject>?, success:(data: NSData?, userInfo: Dictionary<String, AnyObject>?) -> (), failure:(error: NSError) -> ())
    {
        self.init(action: action, parameters: parameters, userInfo: userInfo, receivedData: nil, success: success, failure: failure)
    }
    
    // MARK: - Connection Delegate -
    
    public func connection(connection: NSURLConnection, canAuthenticateAgainstProtectionSpace protectionSpace: NSURLProtectionSpace) -> Bool {
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            return true
        }
        
        return false
    }
    
    public func connection(connection: NSURLConnection, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            challenge.sender.useCredential(NSURLCredential(forTrust: challenge.protectionSpace.serverTrust), forAuthenticationChallenge: challenge)
        }
        
        challenge.sender.continueWithoutCredentialForAuthenticationChallenge(challenge)
    }
    
    public func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        if self._receivedDataHandler == nil {
            self._receivedData?.length = 0
        }
    }
    
    public func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        if let receivedDataHandler = self._receivedDataHandler {
            receivedDataHandler(data: data)
        } else {
            self._receivedData?.appendData(data)
        }
    }
    
    public func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        self._failureHandler(error: error)
    }
    
    public func connectionDidFinishLoading(connection: NSURLConnection) {
        self._successHandler(data: self._receivedData, userInfo: self.userInfo)
    }
}