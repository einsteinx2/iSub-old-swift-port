//
//  HLSSegmentStreamer.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//

import Foundation
import Swifter

final class HLSSegmentStreamer: SelfSignedCertDelegate, URLSessionDataDelegate {
    fileprivate(set) var isStreaming = false
    
    fileprivate let segment: HLSSegment
    fileprivate let writer: HttpResponseBodyWriter
    fileprivate var session: URLSession!
    fileprivate var dataTask: URLSessionDataTask!
    
    init(segment: HLSSegment, writer: HttpResponseBodyWriter) {
        self.segment = segment
        self.writer = writer
        super.init()
    }
    
    func start() {
        session = URLSession(configuration: .background(withIdentifier: "HLSSegmentStreamer"), delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: segment.url)
        if let dataTask = dataTask {
            dataTask.resume()
            isStreaming = true
        }
    }
    
    func cancel() {
        session?.invalidateAndCancel()
        session = nil
        dataTask = nil
        isStreaming = false
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            // Stream the bytes to the client
            let bytes = Array(data)
            try writer.write(bytes)
        } catch {
            // This can happen if the user seeks in the video causing the HTTP connection to close
            cancel()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isStreaming = false
    }
}
