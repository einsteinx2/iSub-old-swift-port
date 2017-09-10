//
//  HLSPlaylistDownloader.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//

import Foundation
import QuartzCore
import Swifter

final class HLSPlaylistDownloader: HLSPlaylistDownloaderDelegate {
    struct Config {
        // The timeout for response of request in seconds
        static let requestTimeout = 3.0
        
        // The timeout for receiving data of request in seconds
        static let resourceTimeout = 10.0
    }
    
    weak var delegate: HLSPlaylistDownloaderDelegate?
        
    let playlistUrl: URL
    let allowSelfSignedCerts: Bool
    
    fileprivate(set) var inputPlaylist: HLSPlaylist?
    fileprivate(set) var outputPlaylist: HLSPlaylist?
    
    fileprivate var session: URLSession?
    fileprivate var playlistTask: URLSessionTask?
    
    fileprivate var subplaylistDownloaders = [HLSPlaylistDownloader]()
    fileprivate var updatedSubplaylists = [HLSPlaylist]()
    
    init(inputPlaylist: HLSPlaylist, allowSelfSignedCerts: Bool = false) {
        self.inputPlaylist = inputPlaylist
        self.playlistUrl = inputPlaylist.url
        self.allowSelfSignedCerts = allowSelfSignedCerts
    }
    
    init(playlistUrl: URL, allowSelfSignedCerts: Bool = false) {
        self.playlistUrl = playlistUrl
        self.allowSelfSignedCerts = allowSelfSignedCerts
    }
    
    func start() {
        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = Config.requestTimeout
        conf.timeoutIntervalForResource = Config.resourceTimeout
        let delegate: URLSessionDelegate? = allowSelfSignedCerts ? SelfSignedCertDelegate.shared : nil
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        playlistTask = session?.dataTask(with: playlistUrl) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 200, let data = data, data.count > 0 {
                let outputPlaylist = HLSPlaylist(url: self.playlistUrl, data: data)
                outputPlaylist.programId = self.inputPlaylist?.programId
                outputPlaylist.bandwidth = self.inputPlaylist?.bandwidth
                outputPlaylist.averageBandwidth = self.inputPlaylist?.averageBandwidth
                outputPlaylist.resolution = self.inputPlaylist?.resolution
                outputPlaylist.codecs = self.inputPlaylist?.codecs
                self.outputPlaylist = outputPlaylist
                
                if outputPlaylist.playlists.count > 0 {
                    // Download sub-playlists
                    for subplaylist in outputPlaylist.playlists {
                        DispatchQueue.main.async {
                            let downloader = HLSPlaylistDownloader(inputPlaylist: subplaylist, allowSelfSignedCerts: self.allowSelfSignedCerts)
                            downloader.delegate = self
                            self.subplaylistDownloaders.append(downloader)
                            downloader.start()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.playlistDownloader(self, didReceivePlaylist: self.outputPlaylist!)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.playlistDownloader(self, didFailWithError: error, urlStatusCode: statusCode)
                }
            }
        }
        if let task = playlistTask {
            task.resume()
        }
    }
    
    func cancel() {
        session?.invalidateAndCancel()
        session = nil
        playlistTask = nil
    }
    
    func playlistDownloader(_ downloader: HLSPlaylistDownloader, didReceivePlaylist playlist: HLSPlaylist) {
        print("Downloaded sub-playlist \(String(describing: downloader.outputPlaylist?.uuid.uuidString))")
        DispatchQueue.main.async {
            if let index = self.subplaylistDownloaders.index(where: { $0.playlistUrl == downloader.playlistUrl }) {
                self.subplaylistDownloaders.remove(at: index)
                if let playlist = downloader.outputPlaylist {
                    self.updatedSubplaylists.append(playlist)
                }
            }
            if self.subplaylistDownloaders.count == 0 {
                // Playlists must be ordered from highest bitrate to lowest, or adaptive switching won't work
                let subplaylists = self.updatedSubplaylists.sorted(by: { $0.bandwidth ?? 0 > $1.bandwidth ?? 0 })
                
                self.outputPlaylist?.playlists = subplaylists
                self.delegate?.playlistDownloader(self, didReceivePlaylist: self.outputPlaylist!)
            }
        }
    }
    
    func playlistDownloader(_ downloader: HLSPlaylistDownloader, didFailWithError error: Error?, urlStatusCode code: Int) {
        // TODO: Maybe do something on failure
        print("Failed to download sub-playlist \(String(describing: downloader.outputPlaylist?.uuid.uuidString)) error: \(String(describing: error)) urlStatusCode: \(code)")
        DispatchQueue.main.async {
            if let index = self.subplaylistDownloaders.index(where: { $0.playlistUrl == downloader.playlistUrl }) {
                self.subplaylistDownloaders.remove(at: index)
                if let playlist = downloader.outputPlaylist {
                    self.updatedSubplaylists.append(playlist)
                }
            }
            if self.subplaylistDownloaders.count == 0 {
                self.outputPlaylist?.playlists = self.updatedSubplaylists
                self.delegate?.playlistDownloader(self, didReceivePlaylist: self.outputPlaylist!)
            }
        }
    }
}

protocol HLSPlaylistDownloaderDelegate: class {
    func playlistDownloader(_ downloader: HLSPlaylistDownloader, didReceivePlaylist playlist: HLSPlaylist)
    func playlistDownloader(_ downloader: HLSPlaylistDownloader, didFailWithError error: Error?, urlStatusCode code: Int)
}
