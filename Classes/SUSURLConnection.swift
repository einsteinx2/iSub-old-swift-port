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
    
    fileprivate var _request: NSMutableURLRequest
    fileprivate var _connection: NSURLConnection?
    fileprivate var _receivedData: NSMutableData?
    
    fileprivate let _receivedDataHandler: ((_ data: Data) -> ())?
    fileprivate let _successHandler: (_ data: Data?, _ userInfo: Dictionary<String, AnyObject>?) -> ()
    fileprivate let _failureHandler: (_ error: NSError) -> ()
    
    public init(action: String, parameters: Dictionary<String, String>?, userInfo: Dictionary<String, AnyObject>?, receivedData: ((_ data: Data) -> ())?, success:@escaping (_ data: Data?, _ userInfo: Dictionary<String, AnyObject>?) -> (), failure:@escaping (_ error: NSError) -> ())
    {
        self.action = action
        self.parameters = parameters
        self.userInfo = userInfo
        
        self._receivedDataHandler = receivedData
        self._successHandler = success
        self._failureHandler = failure
        
        self._request = NSMutableURLRequest(susAction: action, parameters: parameters)
        
        super.init()
        
        if let connection = NSURLConnection(request: self._request as URLRequest, delegate: self) {
            self._connection = connection
            
            if self._receivedDataHandler == nil {
                self._receivedData = NSMutableData()
            }
            
            self._connection?.start()
        } else {
            let code: Int = Int(ISMSErrorCode_CouldNotCreateConnection)
            self._failureHandler(NSError(ismsCode: code))
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
        if self._receivedDataHandler == nil {
            self._receivedData?.length = 0
        }
    }
    
    open func connection(_ connection: NSURLConnection, didReceive data: Data) {
        if let receivedDataHandler = self._receivedDataHandler {
            receivedDataHandler(data)
        } else {
            self._receivedData?.append(data)
        }
    }
    
    open func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        self._failureHandler(error as NSError)
    }
    
    open func connectionDidFinishLoading(_ connection: NSURLConnection) {
        self._successHandler(self._receivedData as Data?, self.userInfo)
    }
}
