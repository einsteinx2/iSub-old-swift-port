//
//  GaplessPlayer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import AVFoundation

fileprivate let deviceNumber: UInt32 = 1
fileprivate let bufferSize: UInt32 = 800
fileprivate let defaultSampleRate: UInt32 = 44100

fileprivate let retryDelay = 2.0
fileprivate let minSizeToFail: Int64 = 15 * 1024 * 1024 // 15MB

final class GaplessPlayer {
    struct Notifications {
        static let songStarted = Notification.Name("GaplessPlayer_songStarted")
        static let songPaused  = Notification.Name("GaplessPlayer_songPaused")
        static let songEnded   = Notification.Name("GaplessPlayer_songEnded")
    }
    
    static let si = GaplessPlayer()
    
    let controller = BassStreamController(deviceNumber: deviceNumber)
    
    let equalizer = Equalizer()
    let visualizer = Visualizer()
    
    // MARK: - Lifecycle -
    
    init() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(routeChanged(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(mediaServicesWereLost(_:)), name: NSNotification.Name.AVAudioSessionMediaServicesWereLost, object: AVAudioSession.sharedInstance())
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(mediaServicesWereReset(_:)), name: NSNotification.Name.AVAudioSessionMediaServicesWereReset, object: AVAudioSession.sharedInstance())
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(readyForPlayback(_:)), name: StreamHandler.Notifications.readyForPlayback)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.AVAudioSessionMediaServicesWereLost, object: AVAudioSession.sharedInstance())
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.AVAudioSessionMediaServicesWereReset, object: AVAudioSession.sharedInstance())
        NotificationCenter.removeObserverOnMainThread(self, name: StreamHandler.Notifications.readyForPlayback, object: nil)
    }
    
    // MARK: - Notifications -
    
    fileprivate var shouldResumeFromInterruption = false
    @objc fileprivate func handleInterruption(_ notification: Notification) {
        if notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSessionInterruptionType.began.rawValue {
            shouldResumeFromInterruption = isPlaying
            pause()
        } else {
            let shouldResume = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt == AVAudioSessionInterruptionOptions.shouldResume.rawValue
            if shouldResumeFromInterruption && shouldResume {
                play()
            }
            
            shouldResumeFromInterruption = false
        }
    }
    
    @objc fileprivate func routeChanged(_ notification: Notification) {
        if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSessionRouteChangeReason.oldDeviceUnavailable.rawValue {
            pause()
        }
    }
    
    @objc fileprivate func mediaServicesWereLost(_ notification: Notification) {
        log.debug("mediaServicesWereLost: \(String(describing: notification.userInfo))")
    }
    
    @objc fileprivate func mediaServicesWereReset(_ notification: Notification) {
        log.debug("mediaServicesWereReset: \(String(describing: notification.userInfo))")
    }
    
    @objc fileprivate func readyForPlayback(_ notification: Notification) {
        guard let song = notification.userInfo?[StreamHandler.Notifications.Keys.song] as? Song else {
            return
        }
        
        if !isPlaying, song == PlayQueue.si.currentSong && (controller.currentBassStream?.song == nil || controller.currentBassStream?.song == song) {
            start(song: song)
        } else if song == PlayQueue.si.nextSong && (controller.nextBassStream?.song == nil || controller.nextBassStream?.song == song) {
            prepareNextStream()
        }
    }
    
    // MARK: - Playback -
    
    var startByteOffset: Int64 = 0
    var isPlaying = false
    
    var isStarted: Bool {
        if let currentBassStream = controller.currentBassStream, currentBassStream.stream != 0 {
            return true
        }
        return false
    }
    
    var currentByteOffset: Int64 {
        if let currentBassStream = controller.currentBassStream {
            return Int64(BASS_StreamGetFilePosition(currentBassStream.stream, DWORD(BASS_FILEPOS_CURRENT))) + startByteOffset
        }
        return 0
    }
    
    var rawProgress: Double {
        guard let currentBassStream = controller.currentBassStream else {
            return 0
        }
        
        BASS_SetDevice(deviceNumber)
        
        var pcmBytePosition = Double(BASS_Mixer_ChannelGetPosition(currentBassStream.stream, DWORD(BASS_POS_BYTE)))
        let chanCount = Double(currentBassStream.channelCount)
        let filledSpace = Double(ringBuffer.filledSpace)
        let sampleRate = Double(currentBassStream.sampleRate)
        let defaultRate = Double(defaultSampleRate)
        let totalDrained = Double(totalBytesDrained)
        
        let denom = (2.0 * (1.0 / chanCount))
        let realPosition = pcmBytePosition - (filledSpace / denom)
        let sampleRateRatio = sampleRate / defaultRate
        
        pcmBytePosition = realPosition
        pcmBytePosition = pcmBytePosition < 0 ? 0 : pcmBytePosition
        let position = totalDrained * sampleRateRatio * chanCount
        if let position = UInt64(exactly: position) {
            let seconds = BASS_ChannelBytes2Seconds(currentBassStream.stream, position)
            return seconds
        }
        
        return 0
    }
    
    var previousSongForProgress: Song?
    
    var progress: Double {
        guard let currentBassStream = controller.currentBassStream else {
            return 0
        }
        
        let seconds = rawProgress
        if seconds < 0 {
            // Use the previous song (i.e the one still coming out of the speakers), since we're actually finishing it right now
            let prevDuration = previousSongForProgress?.duration ?? 0
            return Double(prevDuration) + seconds
        }
        
        return seconds + BASS_ChannelBytes2Seconds(currentBassStream.stream, QWORD(startByteOffset))
    }
    
    var progressPercent: Double {
        guard let currentBassStream = controller.currentBassStream else {
            return 0
        }
        
        var seconds = rawProgress
        
        if let durationInt = previousSongForProgress?.duration {
            let duration = Double(durationInt)
            if seconds < 0 {
                if duration > 0 {
                    seconds = duration + seconds
                    return seconds / duration
                }
                return 0
            }
        }
        
        if let duration = currentBassStream.song.duration, duration > 0 {
            return seconds / Double(duration)
        }
        
        return 0
    }
    
    var bitRate: Int {
        return controller.currentBassStream == nil ? 0 : Bass.estimateBitRate(bassStream: controller.currentBassStream!)
    }
    
    func stop() {
        BASS_SetDevice(deviceNumber)
        
        if isPlaying {
            BASS_Pause()
            isPlaying = false
        }
        
        cleanupOutput()
    }
    
    func play() {
        if !isPlaying {
            playPause()
        }
    }
    
    func pause() {
        if isPlaying {
            playPause()
        }
    }
    
    func playPause() {
        BASS_SetDevice(deviceNumber)
        
        if isPlaying {
            BASS_Pause()
            isPlaying = false
            NotificationCenter.postOnMainThread(name: Notifications.songPaused)
        } else if controller.currentBassStream == nil {
            // See if we're at the end of the playlist
            if PlayQueue.si.currentSong != nil {
                PlayQueue.si.startSong(byteOffset: startByteOffset)
            } else {
                DispatchQueue.main.async {
                    PlayQueue.si.playPreviousSong()
                }
            }
        } else {
            BASS_Start()
            isPlaying = true
            NotificationCenter.postOnMainThread(name: Notifications.songStarted)
        }
    }
    
    func seek(bytes: Int64, fadeDuration: TimeInterval = 0.0) {
        BASS_SetDevice(deviceNumber)
        
        guard let currentBassStream = controller.currentBassStream else {
            return
        }
        
        currentBassStream.isEnded = false
        
        if BASS_Mixer_ChannelSetPosition(currentBassStream.stream, UInt64(bytes), UInt32(BASS_POS_BYTE)) {
            currentBassStream.neededSize = Int64.max
            if currentBassStream.isWaiting {
                currentBassStream.shouldBreakWaitLoop = true
            }
            
            ringBuffer.reset()
            
            if fadeDuration > 0.0 {
                let fadeDurationMillis = UInt32(fadeDuration * 1000)
                BASS_ChannelSlideAttribute(controller.outStream, UInt32(BASS_ATTRIB_VOL), 0, fadeDurationMillis)
            } else {
                BASS_ChannelStop(controller.outStream)
                BASS_ChannelPlay(controller.outStream, false)
            }
            
            totalBytesDrained = Int(Double(bytes) / Double(currentBassStream.channelCount) / (Double(currentBassStream.sampleRate) / Double(defaultSampleRate)))
        } else {
            Bass.printBassError()
        }
    }
    
    func seek(seconds: Double, fadeDuration: TimeInterval = 0.0) {
        if let currentBassStream = controller.currentBassStream {
            BASS_SetDevice(deviceNumber)
            
            let bytes = BASS_ChannelSeconds2Bytes(currentBassStream.stream, seconds)
            seek(bytes: Int64(bytes), fadeDuration: fadeDuration)
        }
    }
    
    func seek(percent: Double, fadeDuration: TimeInterval = 0.0) {
        if let currentBassStream = controller.currentBassStream, let duration = currentBassStream.song.duration {
            let seconds = Double(duration) * percent
            seek(seconds: seconds, fadeDuration: fadeDuration)
        }
    }
    
    // MARK: - Output Stream -
    
    // MARK: Initialization
    
    fileprivate(set) var isAudioSessionActive = false
    fileprivate func activateAudioSession() {
        guard !isAudioSessionActive else {
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            isAudioSessionActive = true
        } catch {
            printError(error)
        }
        
        initializeOutput()
    }
    
    fileprivate func initializeOutput() {
        log.debug("initializeOutput")
        
        // Disable mixing. To be called before BASS_Init.
        BASS_SetConfig(UInt32(BASS_CONFIG_IOS_MIXAUDIO), 0)
        // Set the buffer length to the minimum amount + bufferSize
        BASS_SetConfig(UInt32(BASS_CONFIG_BUFFER), BASS_GetConfig(UInt32(BASS_CONFIG_UPDATEPERIOD)) + bufferSize)
        // Set DSP effects to use floating point math to avoid clipping within the effects chain
        BASS_SetConfig(UInt32(BASS_CONFIG_FLOATDSP), 1)
        // Initialize default device.
        if (BASS_Init(1, defaultSampleRate, 0, nil, nil))
        {
            controller.bassOutputBufferLengthMillis = BASS_GetConfig(UInt32(BASS_CONFIG_BUFFER))
            
            // Eventually replace this workaround with pure Swift
            bassLoadPlugins()
        }
        else
        {
            controller.bassOutputBufferLengthMillis = 0
            printError("Can't initialize device")
            Bass.printBassError()
        }
        
        controller.mixerStream = BASS_Mixer_StreamCreate(UInt32(defaultSampleRate), 2, UInt32(BASS_STREAM_DECODE))
        controller.outStream = BASS_StreamCreate(UInt32(defaultSampleRate), 2, 0, streamProc, bridge(obj: self))
        
        // Add the slide callback to handle fades
        BASS_ChannelSetSync(controller.outStream, UInt32(BASS_SYNC_SLIDE), 0, slideSyncProc, bridge(obj: self))
        
        visualizer.channel = controller.outStream
        equalizer.channel = controller.outStream
        if SavedSettings.si.isEqualizerOn {
            equalizer.enable()
        }
    }
    
    fileprivate func cleanupOutput() {
        log.debug("cleanup")
        
        BASS_SetDevice(deviceNumber)
        
        startSongRetryTimer?.cancel()
        startSongRetryTimer = nil
        nextSongRetryTimer?.cancel()
        nextSongRetryTimer = nil
        ringBufferFillWorkItem?.cancel()
        ringBufferFillWorkItem = nil
        
        controller.cleanup()
        
        BASS_ChannelStop(controller.outStream)
        ringBuffer.reset()
        
        isPlaying = false
    }
    
    // MARK: Ring buffer
    
    fileprivate let ringBuffer = RingBuffer(size: 640 * 1024) // 640KB
    fileprivate var totalBytesDrained = 0
    fileprivate var ringBufferFillWorkItem: DispatchWorkItem?
    fileprivate var waitLoopBassStream: BassStream?
    
    fileprivate func stopFillingRingBuffer() {
        log.debug("stopFillingRingBuffer")
        ringBufferFillWorkItem?.cancel()
        ringBufferFillWorkItem = nil
    }
    
    fileprivate func startFillingRingBuffer() {
        guard ringBufferFillWorkItem == nil else {
            return
        }
        
        log.debug("startFillingRingBuffer")
        
        var workItem: DispatchWorkItem! = nil
        workItem = DispatchWorkItem {
            // Make sure we're using the right device
            BASS_SetDevice(deviceNumber)
            
            // Grab the mixerStream and ringBuffer as local references, so that if cleanup is run, and we're still inside this loop
            // it won't start filling the new buffer
            let ringBuffer = self.ringBuffer
            let mixerStream = self.controller.mixerStream
            
            let readSize = 64 * 1024
            while !workItem.isCancelled {
                // Fill the buffer if there is empty space
                if ringBuffer.freeSpace > readSize {
                    autoreleasepool {
                        /*
                         * Read data to fill the buffer
                         */
                        
                        if let bassStream = self.controller.currentBassStream {
                            let tempBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: readSize)
                            let tempLength = BASS_ChannelGetData(mixerStream, tempBuffer, UInt32(readSize))
                            if tempLength > 0 {
                                bassStream.isSongStarted = true
                                if !ringBuffer.fill(with: tempBuffer, length: Int(tempLength)) {
                                    printError("Overran ring buffer and it was unable to expand")
                                }
                            }
                            tempBuffer.deallocate()
                            
                            /*
                             * Handle pausing to wait for more data
                             */
                            
                            if bassStream.isFileUnderrun && BASS_ChannelIsActive(bassStream.stream) != UInt32(BASS_ACTIVE_STOPPED) {
                                // Get a strong reference to the current song's userInfo object, so that
                                // if the stream is freed while the wait loop is sleeping, the object will
                                // still be around to respond to shouldBreakWaitLoop
                                self.waitLoopBassStream = bassStream
                                
                                // Mark the stream as waiting
                                bassStream.isWaiting = true
                                bassStream.isFileUnderrun = false
                                bassStream.wasFileJustUnderrun = true
                                
                                // Handle waiting for additional data
                                if !bassStream.song.isFullyCached {
                                    // Bail if the thread was canceled
                                    if workItem.isCancelled {
                                        return
                                    }
                                    
                                    if SavedSettings.si.isOfflineMode {
                                        // This is offline mode and the song can not continue to play
                                        self.moveToNextSong()
                                    } else {
                                        // Calculate the needed size:
                                        // Choose either the current player bitRate, or if for some reason it is not detected properly,
                                        // use the best estimated bitRate. Then use that to determine how much data to let download to continue.
                                        let size = bassStream.song.localFileSize
                                        let bitRate = Bass.estimateBitRate(bassStream: bassStream)
                                        
                                        // Get the stream for this song
                                        var recentDownloadSpeedInBytesPerSec = 0
                                        if StreamQueue.si.song == bassStream.song, let handler = StreamQueue.si.streamHandler {
                                            recentDownloadSpeedInBytesPerSec = handler.recentDownloadSpeedInBytesPerSec
                                        } else if DownloadQueue.si.currentSong == bassStream.song, let handler = DownloadQueue.si.streamHandler {
                                            recentDownloadSpeedInBytesPerSec = handler.recentDownloadSpeedInBytesPerSec
                                        }
                                        
                                        // Calculate the bytes to wait based on the recent download speed. If the handler is nil or recent download speed is 0
                                        // it will just use the default (currently 10 seconds)
                                        let bytesToWait = Bass.bytesToBuffer(forKiloBitRate: bitRate, speedInBytesPerSec: recentDownloadSpeedInBytesPerSec)
                                        
                                        bassStream.neededSize = size + bytesToWait
                                        
                                        // Sleep for 100000 microseconds, or 1/10th of a second
                                        let sleepTime: UInt32 = 100000
                                        // Check file size every second, so 1000000 microseconds
                                        let fileSizeCheckWait: UInt32 = 1000000
                                        var totalSleepTime: UInt32 = 0
                                        while true {
                                            // Bail if the thread was canceled
                                            if workItem.isCancelled {
                                                return
                                            }
                                            
                                            // Check if we should break every 10th of a second
                                            usleep(sleepTime)
                                            totalSleepTime += sleepTime
                                            if bassStream.shouldBreakWaitLoop || bassStream.shouldBreakWaitLoopForever {
                                                return
                                            }
                                            
                                            // Bail if the thread was canceled
                                            if workItem.isCancelled {
                                                return
                                            }
                                            
                                            // Only check the file size every second
                                            if totalSleepTime >= fileSizeCheckWait {
                                                autoreleasepool {
                                                    totalSleepTime = 0
                                                    
                                                    if bassStream.song.localFileSize >= bassStream.neededSize {
                                                        // If enough of the file has downloaded, break the loop
                                                        return
                                                    } else if bassStream.song.isTempCached && bassStream.song != StreamQueue.si.song {
                                                        // Handle temp cached songs ending. When they end, they are set as the last temp cached song, so we know it's done and can stop waiting for data.
                                                        return
                                                    } else if bassStream.song.isFullyCached {
                                                        // If the song has finished caching, we can stop waiting
                                                        return
                                                    } else if SavedSettings.si.isOfflineMode {
                                                        // If we're not in offline mode, stop waiting and try next song
                                                        // Bail if the thread was canceled
                                                        if workItem.isCancelled {
                                                            return
                                                        }
                                                        
                                                        self.moveToNextSong()
                                                        return
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Bail if the thread was canceled
                                if workItem.isCancelled {
                                    return
                                }
                                
                                bassStream.isWaiting = false
                                bassStream.shouldBreakWaitLoop = false
                                self.waitLoopBassStream = nil
                            }
                        }
                    }
                }
                
                // Bail if the thread was canceled
                if workItem.isCancelled {
                    return
                }
                
                // Sleep for 1/4th of a second to prevent a tight loop
                usleep(150000)
            }
        }
        
        ringBufferFillWorkItem = workItem
        DispatchQueue.utility.async(execute: workItem)
    }
    
    // MARK: Other
    
    fileprivate var startSongRetryTimer: DispatchSourceTimer?
    func start(song: Song, byteOffset: Int64 = 0) {
        log.debug("start song: \(song)")
        BASS_SetDevice(deviceNumber)
        
        startByteOffset = 0
        
        cleanupOutput()
        
        guard song.fileExists else {
            log.debug("file doesn't exist")
            return
        }
        
        activateAudioSession()
        
        if let bassStream = prepareStream(forSong: song) {
            log.debug("stream created, starting playback")
            BASS_Mixer_StreamAddChannel(controller.mixerStream, bassStream.stream, UInt32(BASS_MIXER_NORAMPIN))
            
            totalBytesDrained = 0
            
            BASS_Start()
            
            // Add the stream to the queue
            controller.add(bassStream: bassStream)
            
            // Skip to the byte offset
            startByteOffset = byteOffset
            totalBytesDrained = Int(byteOffset)
            if byteOffset > 0 {
                seek(bytes: byteOffset)
            }
            
            // Start filling the ring buffer
            startFillingRingBuffer()
            
            // Start playback
            BASS_ChannelPlay(controller.outStream, false)
            isPlaying = true
            
            // Notify listeners that playback has started
            NotificationCenter.postOnMainThread(name: Notifications.songStarted)
            
            song.lastPlayed = Date()
            
            if let nextSong = PlayQueue.si.nextSong, nextSong.isFullyCached || nextSong.isPartiallyCached {
                prepareNextStream()
            }
        } else if !song.isFullyCached && song.localFileSize < minSizeToFail {
            log.debug("failed to create stream for: \(song.title)")
            if SavedSettings.si.isOfflineMode {
                moveToNextSong()
                log.debug("offline so moving to next song")
            } else if !song.fileExists {
                log.debug("file doesn't exist somehow, so restarting playback")
                // File was removed, so start again normally
                CacheManager.si.remove(song: song)
                PlayQueue.si.startSong()
            } else {
                log.debug("retrying stream in 2 seconds")
                // Failed to create the stream, retrying
                startSongRetryTimer?.cancel()
                startSongRetryTimer = DispatchSource.makeTimerSource(queue: .main)
                startSongRetryTimer?.setEventHandler {
                    self.start(song: song, byteOffset: byteOffset)
                }
                startSongRetryTimer?.schedule(deadline: .now() + 2.0)
                startSongRetryTimer?.resume()
            }
        } else {
            CacheManager.si.remove(song: song)
            PlayQueue.si.startSong()
        }
    }
    
    fileprivate func prepareStream(forSong song: Song) -> BassStream? {
        log.debug("preparing stream for song: \(song)")
        guard song.fileExists, let bassStream = BassStream(song: song) else {
            if song.fileExists {
                log.debug("couldn't create bass stream")
            } else {
                log.debug("file doesn't exist")
            }
            
            return nil
        }
        
        BASS_SetDevice(deviceNumber)
        
        func createStream(softwareDecoding: Bool = false) -> HSTREAM {
            var flags = BASS_STREAM_DECODE | BASS_SAMPLE_FLOAT
            if softwareDecoding {
                flags = flags | BASS_SAMPLE_SOFTWARE
            }
            return BASS_StreamCreateFileUser(UInt32(STREAMFILE_NOBUFFER), UInt32(flags), &fileProcs, bridge(obj: bassStream))
        }
        
        // Try and create the stream
        var fileStream = createStream()
        
        // Check if the stream failed because of a BASS_Init error and init if needed
        if fileStream == 0 && BASS_ErrorGetCode() == BASS_ERROR_INIT {
            log.debug("bass not initialized, calling initializeOutput")
            initializeOutput()
            fileStream = createStream()
        }
        
        // If the stream failed, try with softrware decoding
        if fileStream == 0 {
            Bass.printBassError()
            log.debug("failed to create stream, trying again with software decoding")
            fileStream = createStream(softwareDecoding: true)
        }
        
        if fileStream > 0 {
            // Add the stream free callback
            BASS_ChannelSetSync(fileStream, UInt32(BASS_SYNC_END|BASS_SYNC_MIXTIME), 0, endSyncProc, bridge(obj: bassStream))
            
            // Ask BASS how many channels are on this stream
            var info = BASS_CHANNELINFO()
            BASS_ChannelGetInfo(fileStream, &info)
            bassStream.channelCount = Int(info.chans)
            bassStream.sampleRate = Int(info.freq)
            
            // Stream successfully created
            bassStream.stream = fileStream
            bassStream.player = self
            return bassStream
        }
        
        Bass.printBassError()
        log.debug("failed to create stream")
        return nil
    }
    
    fileprivate var nextSongRetryTimer: DispatchSourceTimer?
    fileprivate func prepareNextStream() {
        if controller.nextBassStream == nil, let nextSong = PlayQueue.si.nextSong {
            log.debug("prepareNextStream called for: \(nextSong.title)")
            DispatchQueue.utility.async {
                if let nextStream = self.prepareStream(forSong: nextSong) {
                    log.debug("prepareStream succeeded for: \(nextSong.title)")
                    self.controller.add(bassStream: nextStream)
                } else {
                    log.debug("prepareStream failed for: \(nextSong.title)")
                    self.nextSongRetryTimer?.cancel()
                    self.nextSongRetryTimer = DispatchSource.makeTimerSource(queue: .main)
                    self.nextSongRetryTimer?.setEventHandler {
                        self.prepareNextStream()
                    }
                    self.nextSongRetryTimer?.schedule(deadline: .now() + 2.0)
                    self.nextSongRetryTimer?.resume()
                    
                    self.controller.currentBassStream?.isNextSongStreamFailed = true
                }
            }
        }
    }
    
    fileprivate func nextSongStreamFailed() {
        log.debug("next song stream failed")
        
        // The song ended, and we tried to make the next stream but it failed
        if let song = PlayQueue.si.currentSong {
            log.debug("song: \(song)")
            if let handler = StreamQueue.si.streamHandler, song == StreamQueue.si.song {
                log.debug("handler and song exist")
                if handler.isReadyForPlayback {
                    // If the song is downloading and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                    log.debug("song is ready for playback, asynchronously calling startSong")
                    DispatchQueue.main.async {
                        self.prepareNextStream()
                        //self.start(song: song)
                        //PlayQueue.si.startSong()
                    }
                }
            } else if song.isFullyCached {
                log.debug("song is fully cached, asynchronously calling startSong")
                DispatchQueue.main.async {
                    self.start(song: song)
                    //PlayQueue.si.startSong()
                }
            } else {
                log.debug("calling start on StreamQueue")
                StreamQueue.si.start()
            }
        }
    }
    
    fileprivate func moveToNextSong() {
        if PlayQueue.si.nextSong != nil {
            log.debug("playing next song")
            PlayQueue.si.playNextSong()
        } else {
            log.debug("calling cleanup")
            cleanupOutput()
        }
    }
    
    fileprivate var lastProgressSaveDate = Date.distantPast
    fileprivate let progressSaveInterval = 10.0
    fileprivate func bassGetOutputData(buffer: UnsafeMutableRawPointer?, length: UInt32) -> UInt32 {
        guard let currentBassStream = controller.currentBassStream, let buffer = buffer else {
            return 0
        }
        
        let bytesRead = ringBuffer.drain(into: buffer, length: Int(length))
        totalBytesDrained += bytesRead
        
        if currentBassStream.isEnded {
            currentBassStream.bufferSpaceTilSongEnd -= bytesRead
            if currentBassStream.bufferSpaceTilSongEnd <= 0 {
                songEnded(bassStream: currentBassStream)
                currentBassStream.isEndedCalled = true
            }
        }
        
        let currentSong = currentBassStream.song
        if bytesRead == 0 && BASS_ChannelIsActive(currentBassStream.stream) == UInt32(BASS_ACTIVE_STOPPED) && (currentSong.isFullyCached || currentSong.isTempCached) {
            isPlaying = false
            
            if !currentBassStream.isEndedCalled {
                // Somehow songEnded: was never called
                songEnded(bassStream: currentBassStream)
                currentBassStream.isEndedCalled = true
            }
            
            NotificationCenter.postOnMainThread(name: Notifications.songEnded)
            
            DispatchQueue.main.async {
                self.cleanupOutput()
            }
            
            // Start the next song if for some reason this one isn't ready
            PlayQueue.si.startSong()
            
            return BASS_STREAMPROC_END
        }
        
        let now = Date()
        if now.timeIntervalSince(lastProgressSaveDate) > progressSaveInterval {
            SavedSettings.si.seekTime = progress
            lastProgressSaveDate = now
        }
        
        return UInt32(bytesRead)
    }
    
    // NOTE: this is called AFTER endSyncProc, so the next song is already actually decoding into the ring buffer
    fileprivate func songEnded(bassStream: BassStream) {
        BASS_SetDevice(deviceNumber)
        
        autoreleasepool {
            self.previousSongForProgress = bassStream.song
            self.totalBytesDrained = 0
            
            bassStream.isEndedCalled = true
            
            log.debug("song ended: \(bassStream.song)")
            
            // Remove the stream from the queue
            self.controller.remove(bassStream: bassStream)
            
            // Send song end notification
            NotificationCenter.postOnMainThread(name: Notifications.songEnded)
            
            if self.isPlaying {
                self.startByteOffset = 0
                
                // Send song start notification
                NotificationCenter.postOnMainThread(name: Notifications.songStarted)
                
                // Mark the last played time in the database for cache cleanup
                self.controller.currentBassStream?.song.lastPlayed = Date()
            }
            
            prepareNextStream()
            
//            if bassStream.isNextSongStreamFailed {
//                nextSongStreamFailed()
//            }
        }
    }
}

// MARK: - BASS Callback Functions -

fileprivate func streamProc(handle: HSYNC, buffer: UnsafeMutableRawPointer?, length: UInt32, userInfo: UnsafeMutableRawPointer?) -> UInt32 {
    var bytesRead: UInt32 = 0
    if let userInfo = userInfo {
        autoreleasepool {
            let player: GaplessPlayer = bridge(ptr: userInfo)
            bytesRead = player.bassGetOutputData(buffer: buffer, length: length)
        }
    }
    return bytesRead
}

// MARK: File Procs

fileprivate var fileProcs = BASS_FILEPROCS(close: closeProc, length: lengthProc, read: readProc, seek: seekProc)

fileprivate func closeProc(userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo = userInfo else {
        return
    }
    
    autoreleasepool {
        // Get the user info object
        let bassStream: BassStream = bridge(ptr: userInfo)
        
        log.debug("close proc called for: \(bassStream.song.title)")
        
        // Tell the read wait loop to break in case it's waiting
        bassStream.shouldBreakWaitLoop = true
        bassStream.shouldBreakWaitLoopForever = true
        
        do {
            try ObjC.catchException({bassStream.fileHandle.closeFile()})
        } catch {
            printError(error)
        }
    }
}

fileprivate func lengthProc(userInfo: UnsafeMutableRawPointer?) -> UInt64 {
    guard let userInfo = userInfo else {
        return 0
    }

    var length: Int64 = 0
    autoreleasepool {
        let bassStream: BassStream = bridge(ptr: userInfo)
        if bassStream.song.isFullyCached || bassStream.isTempCached {
            // Return actual file size on disk
            log.debug("using song.localFileSize")
            length = bassStream.song.localFileSize
        } else {
            // Return server reported file size
            log.debug("using bassStream.song.size")
            length = bassStream.song.size
        }

        log.debug("length proc called for: \(bassStream.song.title) len: \(length)")
    }

    return UInt64(length)
}

fileprivate func readProc(buffer: UnsafeMutableRawPointer?, length: UInt32, userInfo: UnsafeMutableRawPointer?) -> UInt32 {
    guard let buffer = buffer, let userInfo = userInfo else {
        return 0
    }
    
    let bufferPointer = UnsafeMutableBufferPointer(start: buffer.assumingMemoryBound(to: UInt8.self), count: Int(length))
    var bytesRead: UInt32 = 0
    autoreleasepool {
        let bassStream: BassStream = bridge(ptr: userInfo)
        
        // Read from the file
        var readData = Data()
        do {
            try ObjC.catchException {
                readData = bassStream.fileHandle.readData(ofLength: Int(length))
            }
        } catch {
            // NOTE: Turned this off for now as it's giving NSFileHandleOperationException logs during normal operation
            //printError(error)
        }
        
        bytesRead = UInt32(readData.count)
        if bytesRead > 0 {
            // Copy the data to the buffer
            bytesRead = UInt32(readData.copyBytes(to: bufferPointer))
        }
        
        if bytesRead < length && bassStream.isSongStarted && !bassStream.wasFileJustUnderrun {
            bassStream.isFileUnderrun = true
        }
        
        bassStream.wasFileJustUnderrun = false
    }
    
    return bytesRead
}

fileprivate func seekProc(offset: UInt64, userInfo: UnsafeMutableRawPointer?) -> ObjCBool {
    guard let userInfo = userInfo else {
        return false
    }
    
    var success = false
    autoreleasepool {
        // Seek to the requested offset (returns false if data not downloaded that far)
        let bassStream: BassStream = bridge(ptr: userInfo)
        
        // First check the file size to make sure we don't try and skip past the end of the file
        let localFileSize = bassStream.song.localFileSize
        if localFileSize >= 0 && UInt64(localFileSize) >= offset {
            // File size is valid, so assume success unless the seek operation throws an exception
            success = true
            do {
                try ObjC.catchException {
                    bassStream.fileHandle.seek(toFileOffset: offset)
                }
            } catch {
                success = false
            }
        }
        
        log.debug("seekProc called for: \(bassStream.song.title) success: \(success) localFileSize: \(localFileSize)")
    }
    return ObjCBool(success)
}

// MARK: Sync Procs

fileprivate func slideSyncProc(handle: HSYNC, channel: UInt32, data: UInt32, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo = userInfo else {
        return
    }
    
    BASS_SetDevice(deviceNumber)
    
    autoreleasepool {
        let player: GaplessPlayer = bridge(ptr: userInfo)
        
        var volumeLevel: Float = 0
        let success = BASS_ChannelGetAttribute(player.controller.outStream, UInt32(BASS_ATTRIB_VOL), &volumeLevel)
        
        if success && volumeLevel == 0.0 {
            BASS_ChannelSlideAttribute(player.controller.outStream, UInt32(BASS_ATTRIB_VOL), 1, 200)
        }
    }
}

fileprivate func endSyncProc(handle: HSYNC, channel: UInt32, data: UInt32, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo = userInfo else {
        return
    }
    
    // Make sure we're using the right device
    BASS_SetDevice(deviceNumber)
    
    autoreleasepool {
        let bassStream: BassStream = bridge(ptr: userInfo)
        if let player = bassStream.player {
            log.debug("endSyncProc called for: \(bassStream.song.title)")
            
            // Mark as ended and set the buffer space til end for the UI
            bassStream.bufferSpaceTilSongEnd = player.ringBuffer.filledSpace
            bassStream.isEnded = true
            
            if let nextStream = player.controller.nextBassStream {
                BASS_Mixer_StreamAddChannel(player.controller.mixerStream, nextStream.stream, UInt32(BASS_MIXER_NORAMPIN))
            }
        }
    }
}
