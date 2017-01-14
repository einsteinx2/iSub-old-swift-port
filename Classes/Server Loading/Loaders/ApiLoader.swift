//
//  ApiLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/10/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import Async

enum ApiLoaderState {
    case new
    case loading
    case canceled
    case failed
    case finished
}

typealias ApiLoaderCompletionHandler = (_ success: Bool, _ error: Error?, _ loader: ApiLoader) -> Void

@objc protocol ApiLoaderDelegate {
    @objc optional func loadingRedirected(_ loader: ApiLoader, redirectUrl url: URL)
    func loadingFailed(_ loader: ApiLoader, withError error: Error?)
    func loadingFinished(_ loader: ApiLoader)
}

class ApiLoader: NSObject, URLSessionDataDelegate {
    // Queue for background loading of additional models. I.e. If you load a folder, 
    // to ensure you get all artist and album records needed
    // TODO: Save the contents of this queue in case the app closes or crashes or the server goes down
    static var backgroundLoadingQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    
    var completionHandler: ApiLoaderCompletionHandler?
    var delegate: ApiLoaderDelegate?
    
    fileprivate(set) var state = ApiLoaderState.new
    fileprivate(set) var redirectUrl: URL?
    
    var redirectUrlString: String? {
        if let url = redirectUrl, let scheme = url.scheme, let host = url.host {
            var redirectUrlString = "\(scheme)://\(host)"
            if let port = url.port {
                redirectUrlString += ":\(port)"
            }
            if url.pathComponents.count > 3 {
                for component in url.pathComponents {
                    if component == "api" || component == "rest" {
                        break
                    }
                    
                    if component != "/" {
                        redirectUrlString += "/\(component)"
                    }
                }
            }
            return redirectUrlString
        }
        return nil
    }
    
    fileprivate var request: URLRequest?
    fileprivate var session: URLSession?
    fileprivate var task: URLSessionDataTask?
    fileprivate var receivedData = Data()
    
    fileprivate var selfRef: ApiLoader?
    
    override init() {
        super.init()
    }
    
    init(delegate: ApiLoaderDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    init(completionHandler: @escaping ApiLoaderCompletionHandler) {
        self.completionHandler = completionHandler
        super.init()
    }
    
    func createRequest() -> URLRequest {
        fatalError("Must override in subclass")
    }
    
    func processResponse(root: RXMLElement) {
        fatalError("Must override in subclass")
    }
    
    func start() {
        guard state != .loading else {
            return
        }
        
        request = createRequest()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task = session!.dataTask(with: request!)
        task!.resume()
        
        state = .loading
        
        if selfRef == nil {
            selfRef = self
        }
    }
    
    func cancel() {
        if state == .loading {
            task?.cancel()
            receivedData = Data()
            session = nil
            
            state = .canceled
            selfRef = nil
        }
    }
    
    func finished() {
        state = .finished
        
        delegate?.loadingFinished(self)
        completionHandler?(true, nil, self)
    }
    
    func failed(error: Error?) {
        state = .failed
        
        delegate?.loadingFailed(self, withError: error)
        completionHandler?(false, error, self)
        
        selfRef = nil
    }
    
    // MARK: - URLSession Delegate -
    
    @objc(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:) func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler completion: @escaping (URLRequest?) -> Void) {
        if let url = request.url {
            redirectUrl = url
            delegate?.loadingRedirected?(self, redirectUrl: url)
        }
        completion(request)
    }
 
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        receivedData = Data()
        completionHandler(.allow)
    }
 
    // Allow self signed certs
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential())
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            receivedData = Data()
            if (error as NSError).domain == NSURLErrorDomain, (error as NSError).code == NSURLErrorCancelled {
                selfRef = nil
            } else {
                Async.main {
                    self.failed(error: error)
                }
            }
        } else {
            guard let root = RXMLElement(fromXMLData: receivedData), root.isValid else {
                Async.main {
                    self.failed(error: NSError(ismsCode: ISMSErrorCode_NotXML))
                }
                return
            }
            
            if let error = root.child("error"), error.isValid {
                let code = error.attribute("code") ?? "-1"
                let message = error.attribute("message") ?? ""
                let error = NSError(domain: SUSErrorDomain, code: Int(code) ?? -1, userInfo: [NSLocalizedDescriptionKey: message])
                Async.main {
                    self.failed(error: error)
                }
            } else {
                processResponse(root: root)
                Async.main {
                    self.finished()
                }
            }
        }
    }
}
