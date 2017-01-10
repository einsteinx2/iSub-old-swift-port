//
//  StatusLoader.swift
//  Pods
//
//  Created by Benjamin Baron on 2/12/16.
//
//

import Foundation

class StatusLoader: ApiLoader {
    
    fileprivate(set) var server: Server?
    
    fileprivate(set) var url: String
    fileprivate(set) var username: String
    fileprivate(set) var password: String

    fileprivate(set) var versionString: String?
    fileprivate(set) var majorVersion: Int?
    fileprivate(set) var minorVersion: Int?
    
    convenience init(server: Server) {
        // TODO: Handle this case better, should only happen if there's a keychain problem
        let password = server.password ?? ""
        self.init(url: server.url, username: server.username, password: password)
        self.server = server
    }
    
    init(url: String, username: String, password: String) {
        self.url = url
        self.username = username
        self.password = password
        super.init()
    }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "ping", urlString: url, username: username, password: password, parameters: nil, fragment: nil, byteOffset: 0) as URLRequest?        
    }
    
    override func processResponse(root: RXMLElement) {
        if root.tag == "subsonic-response" {
            self.versionString = root.attribute("version")
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
            
            NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckPassed)
        }
        else
        {
            // This is not a Subsonic server, so fail
            self.failed(error: NSError(ismsCode: ISMSErrorCode_NotASubsonicServer))
            NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
        }
    }
    
    override func failed(error: Error?) {
        if let error = error as? NSError {
            if error.code == 40 {
                // Incorrect credentials, so fail
                NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
                super.failed(error: NSError(ismsCode: ISMSErrorCode_IncorrectCredentials))
                return
            } else if error.code == 60 {
                // Subsonic trial ended
                NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ServerCheckFailed)
                super.failed(error: NSError(ismsCode: ISMSErrorCode_SubsonicTrialOver))
                return
            }
        }
        
        super.failed(error: error)
    }
}
