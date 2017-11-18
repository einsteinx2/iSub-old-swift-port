//
//  HLSProxyServer.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//
// Loosely based on the example code here: https://github.com/kencool/KSHLSPlayer
//

import Foundation
import Swifter

final class HLSProxyServer {
    struct Config {
        static let playlistFailureMax = 10
        static let playlistFilename = "stream.m3u8"
        static let hlsVersion = 3
        static let defaultPort: UInt16 = 9999
    }
        
    weak var delegate: HLSProxyServerDelegate?
    
    fileprivate let playlistUrl: URL
    fileprivate var allowSelfSignedCerts: Bool
    fileprivate var playlistDownloader: HLSPlaylistDownloader!
 
    fileprivate var httpServer: HttpServer?
    fileprivate var localServiceUrl: String { return "http://localhost:\(Config.defaultPort)" }
    fileprivate var localPlaylistUrl: String { return localServiceUrl + "/" + Config.playlistFilename }
    
    fileprivate(set) var streaming = false
    fileprivate var serviceReadyNotified = false
    fileprivate var playlistFailureTimes = 0
    
    public init(playlistUrl: URL, allowSelfSignedCerts: Bool = false) {
        self.playlistUrl = playlistUrl
        self.allowSelfSignedCerts = allowSelfSignedCerts
    }
    
    @discardableResult func start() -> Bool {
        if streaming {
            return false
        }
        
        streaming = true
        serviceReadyNotified = false
        playlistFailureTimes = 0
        
        // Prepare http server
        do {
            try prepareHttpServer()
        } catch {
            print("Failed to start http server")
            return false
        }
        
        // Prepare receiver
        playlistDownloader = HLSPlaylistDownloader(playlistUrl: playlistUrl, allowSelfSignedCerts: allowSelfSignedCerts)
        playlistDownloader.delegate = self
        playlistDownloader.start()
        
        return true
    }
    
    func stop() {
        streaming = false
        httpServer?.stop()
        playlistDownloader?.cancel()
        playlistDownloader = nil
    }
    
    fileprivate func generatePlaylistResponse(uuidString: String? = nil) -> String? {
        var inputPlaylist = playlistDownloader?.outputPlaylist
        if let uuidString = uuidString {
            inputPlaylist = playlistDownloader?.outputPlaylist?.playlist(withUuidString: uuidString)
        }
        
        if let inputPlaylist = inputPlaylist {
            // Don't put a type if it's a multi-bitrate playlist or it won't play
            var overrideType: HLSPlaylist.StreamType? = .vod
            if inputPlaylist.playlists.count > 0 {
                overrideType = nil
            }
            
            return inputPlaylist.generate(localServiceUrl, overrideType: overrideType, overrideVersion: 3)
        }
        return nil
    }

    fileprivate func prepareHttpServer() throws {
        httpServer = HttpServer()
        if let server = httpServer {
            func playlistHandler(response: String) -> HttpResponse {
                return .raw(200, "OK", ["Content-Type": "application/x-mpegURL; charset=utf-8"], { writer in
                    do {
                        let data = [UInt8](response.utf8)
                        try writer.write(data)
                    } catch {
                        print("Failed to send playlist with error: \(error)")
                    }
                })
            }
            
            // Main playlist
            server["/\(Config.playlistFilename)"] = { [weak self] request in
                if let response = self?.generatePlaylistResponse() {
                    return playlistHandler(response: response)
                }
                
                return .notFound
            }
            
            // Sub-playlist
            server["/playlist/:fileName"] = { [weak self] request in
                if let fileName = request.params[":fileName"], fileName.hasSuffix(".m3u8") {
                    let uuidString = fileName.substring(to: fileName.count - ".m3u8".count)
                    if let response = self?.generatePlaylistResponse(uuidString: uuidString) {
                       return playlistHandler(response: response)
                    }
                }
                
                return .notFound
            }
            
            // Segment
            server["/segment/:uuidString/:fileName"] = { [weak self] request in
                if let uuidString = request.params[":uuidString"], let fileName = request.params[":fileName"], fileName.hasSuffix(".ts") {
                    if let playlist = self?.playlistDownloader?.outputPlaylist?.playlist(withUuidString: uuidString), let segment = playlist.segmentNames[fileName] {
                        return .raw(200, "OK", ["Content-Type": "video/MP2T"], { writer in
                            let streamer = HLSSegmentStreamer(segment: segment, writer: writer)
                            streamer.start()
                            while streamer.isStreaming {
                                Thread.sleep(forTimeInterval: 0.1)
                            }
                        })
                    }
                }
                
                return .notFound
            }

            try server.start(Config.defaultPort)
        }
    }
    
    fileprivate func serviceDidReady() {
        if serviceReadyNotified {
            return
        }
        
        if let url = URL(string: localPlaylistUrl), delegate != nil  {
            serviceReadyNotified = true
            DispatchQueue.main.async {
                self.delegate?.hlsProxyServer(self, streamIsReady: url)
            }
        }
    }
}

extension HLSProxyServer: HLSPlaylistDownloaderDelegate {
    func playlistDownloader(_ downloader: HLSPlaylistDownloader, didReceivePlaylist playlist: HLSPlaylist) {
        if playlistFailureTimes > 0 {
            playlistFailureTimes = 0
        }
        
        serviceDidReady()
    }
    
    func playlistDownloader(_ downloader: HLSPlaylistDownloader, didFailWithError error: Error?, urlStatusCode code: Int) {
        if code == 404 {
            DispatchQueue.main.async {
                self.delegate?.hlsProxyServer(self, streamDidFail: .playlistNotFound)
            }
            stop()
        } else if code == 403 {
            DispatchQueue.main.async {
                self.delegate?.hlsProxyServer(self, streamDidFail: .accessDenied)
            }
            stop()
        } else {
            playlistFailureTimes += 1
            if playlistFailureTimes > Config.playlistFailureMax {
                DispatchQueue.main.async {
                    self.delegate?.hlsProxyServer(self, streamDidFail: .playlistUnavailable)
                }
                stop()
            }
        }
    }
}

protocol HLSProxyServerDelegate: class {
    func hlsProxyServer(_ server: HLSProxyServer, streamIsReady url: URL)
    func hlsProxyServer(_ server: HLSProxyServer, streamDidFail error: HLSProxyError)
    func hlsProxyServer(_ server: HLSProxyServer, playlistDidEnd playlist: HLSPlaylist)
}
