//
//  StatusLoader.swift
//  Pods
//
//  Created by Benjamin Baron on 2/12/16.
//
//

import Foundation

final class StatusLoader: ApiLoader {
    
    fileprivate(set) var server: Server?
    
    fileprivate(set) var url: String
    fileprivate(set) var username: String
    fileprivate(set) var password: String
    fileprivate(set) var basicAuth: Bool
    fileprivate(set) var legacyAuth: Bool

    fileprivate(set) var versionString: String?
    fileprivate(set) var majorVersion: Int?
    fileprivate(set) var minorVersion: Int?
    
    convenience init(server: Server) {
        let password = server.password ?? ""
        self.init(url: server.url, username: server.username, password: password, legacyAuth: server.legacyAuth, basicAuth: server.basicAuth)
        self.server = server
    }
    
    init(url: String, username: String, password: String, legacyAuth: Bool, basicAuth: Bool = false, serverId: Int64? = nil) {
        self.url = url
        self.username = username
        self.password = password
        self.basicAuth = basicAuth
        self.legacyAuth = legacyAuth
        if let serverId = serverId {
            super.init(serverId: serverId)
        } else {
            super.init()
        }
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .ping, baseUrl: url, username: username, password: password, basicAuth: basicAuth, legacyAuth: legacyAuth)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
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
            return true
        } else {
            // This is not a Subsonic server, so fail
            DispatchQueue.main.async {
                self.failed(error: NSError(iSubCode: .notSubsonicServer))
            }
            return false
        }
    }
    
    override func failed(error: Error?) {
        if let error = error {
            if error.code == 40 {
                // Incorrect credentials, so fail
                super.failed(error: NSError(iSubCode: .invalidCredentials))
                return
            } else if error.code == 60 {
                // Subsonic trial ended
                super.failed(error: NSError(iSubCode: .subsonicTrialExpired))
                return
            } else if error.code == 41 && !self.legacyAuth {
                // Token auth not supported, we should probably try legacy
                super.failed(error: NSError(iSubCode: .tokenAuthNotSupported))
                return
            }
        }
        
        super.failed(error: error)
    }
}
