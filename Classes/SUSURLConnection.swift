//
//  SUSURLConnection.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation

@objc open class SUSURLConnection: NSObject, NSURLConnectionDataDelegate {
    
    open let action: String
    open let parameters: Dictionary<String, String>?
    open let userInfo: Dictionary<String, AnyObject>?
    
    fileprivate var request: NSMutableURLRequest
    fileprivate var connection: NSURLConnection?
    fileprivate var receivedData: NSMutableData?
    
    fileprivate let receivedDataHandler: ((_ data: Data) -> ())?
    fileprivate let successHandler: (_ data: Data?, _ userInfo: Dictionary<String, AnyObject>?) -> ()
    fileprivate let failureHandler: (_ error: NSError) -> ()
    
    public init(action: String, parameters: Dictionary<String, String>?, userInfo: Dictionary<String, AnyObject>?, receivedData: ((_ data: Data) -> ())?, success:@escaping (_ data: Data?, _ userInfo: Dictionary<String, AnyObject>?) -> (), failure:@escaping (_ error: NSError) -> ())
    {
        self.action = action
        self.parameters = parameters
        self.userInfo = userInfo
        
        self.receivedDataHandler = receivedData
        self.successHandler = success
        self.failureHandler = failure
        
        self.request = NSMutableURLRequest(susAction: action, parameters: parameters)
        
        super.init()
        
        if let connection = NSURLConnection(request: self.request as URLRequest, delegate: self) {
            self.connection = connection
            
            if self.receivedDataHandler == nil {
                self.receivedData = NSMutableData()
            }
            
            connection.start()
        } else {
            let code: Int = Int(ISMSErrorCode_CouldNotCreateConnection)
            self.failureHandler(NSError(ismsCode: code))
        }
    }
    
    public convenience init(action: String, parameters: Dictionary<String, String>?, userInfo: Dictionary<String, AnyObject>?, success:@escaping (_ data: Data?, _ userInfo: Dictionary<String, AnyObject>?) -> (), failure:@escaping (_ error: NSError) -> ())
    {
        self.init(action: action, parameters: parameters, userInfo: userInfo, receivedData: nil, success: success, failure: failure)
    }
    
    // MARK: - Connection Delegate -
    
    open func connection(_ connection: NSURLConnection, canAuthenticateAgainstProtectionSpace protectionSpace: URLProtectionSpace) -> Bool {
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            return true
        }
        
        return false
    }
    
    open func connection(_ connection: NSURLConnection, didReceive challenge: URLAuthenticationChallenge) {
        guard let sender = challenge.sender, let serverTrust = challenge.protectionSpace.serverTrust else {
            return
        }
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            sender.use(URLCredential(trust: serverTrust), for: challenge)
        }
        
        sender.continueWithoutCredential(for: challenge)

    }
    
    open func connection(_ connection: NSURLConnection, didReceive response: URLResponse) {
        if receivedDataHandler == nil {
            receivedData?.length = 0
        }
    }
    
    open func connection(_ connection: NSURLConnection, didReceive data: Data) {
        if let receivedDataHandler = receivedDataHandler {
            receivedDataHandler(data)
        } else {
            receivedData?.append(data)
        }
    }
    
    open func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        failureHandler(error as NSError)
    }
    
    open func connectionDidFinishLoading(_ connection: NSURLConnection) {
        successHandler(receivedData as Data?, self.userInfo)
    }
}
