//
//  StatusLoader.swift
//  Pods
//
//  Created by Benjamin Baron on 2/12/16.
//
//

import Foundation

@objc(ISMSStatusLoader)
open class StatusLoader: ISMSLoader {
    
    open fileprivate(set) var server: Server?
    
    open fileprivate(set) var url: String
    open fileprivate(set) var username: String
    open fileprivate(set) var password: String

    open fileprivate(set) var versionString: String?
    open fileprivate(set) var majorVersion: Int?
    open fileprivate(set) var minorVersion: Int?
    
    public convenience init(server: Server) {
        // TODO: Handle this case better, should only happen if there's a keychain problem
        let password = server.password ?? ""
        self.init(url: server.url, username: server.username, password: password)
        self.server = server
    }
    
    public init(url: String, username: String, password: String) {
        self.url = url
        self.username = username
        self.password = password
        super.init()
    }
    
    open override var type: ISMSLoaderType {
        return .status
    }
    
    open override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "ping", urlString:self.url, username:self.username, password:self.password, parameters: nil) as URLRequest?
    }
    
    open override func processResponse() {
        let root = RXMLElement(fromXMLData: self.receivedData)
        
        if !(root?.isValid)! {
            let error = NSError(ismsCode: ISMSErrorCode_NotXML)
            self.informDelegateLoadingFailed(error)
            NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
        } else {
            if root?.tag == "subsonic-response" {
                self.versionString = root?.attribute("version")
                if let versionString = self.versionString {
                    let splitVersion = versionString.components(separatedBy: ".")
                    let count = splitVersion.count
                    if count > 0 {
                        self.majorVersion = Int(splitVersion[0])
                        
                        if count > 1 {
                            self.minorVersion = Int(splitVersion[1])
                        }
                    }
                }
                
                
                let error = root?.child("error")
                if error != nil && (error?.isValid)! {
                    let code = Int((error?.attribute("code"))!)
                    if code == 40 {
                        // Incorrect credentials, so fail
                        self.informDelegateLoadingFailed(NSError(ismsCode: ISMSErrorCode_IncorrectCredentials))
                        NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
                    } else if code == 60 {
                        // Incorrect credentials, so fail
                        self.informDelegateLoadingFailed(NSError(ismsCode: ISMSErrorCode_SubsonicTrialOver))
                        NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
                    } else {
                        // This is a Subsonic server, so pass
                        self.informDelegateLoadingFinished()
                        NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckPassed)
                    }
                } else {
                    // This is a Subsonic server, so pass
                    self.informDelegateLoadingFinished()
                    NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckPassed)
                }
            }
            else
            {
                // This is not a Subsonic server, so fail
                self.informDelegateLoadingFailed(NSError(ismsCode: ISMSErrorCode_NotASubsonicServer))
                NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
            }
        }
    }
}
