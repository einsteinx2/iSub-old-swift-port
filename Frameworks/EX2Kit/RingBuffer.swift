//
//  RingBuffer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/26/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class RingBuffer {
    fileprivate let lock = NSRecursiveLock()
    fileprivate var buffer: UnsafeMutablePointer<UInt8>
    fileprivate var readPosition: Int = 0
    fileprivate var writePosition: Int = 0
    
    fileprivate(set) var size: Int
    var maximumSize: Int
    
    var freeSpace: Int {
        return lock.synchronizedResult {
            return size - filledSpace
        }
    }
    
    var filledSpace: Int {
        return lock.synchronizedResult {
            if readPosition <= writePosition {
                return writePosition - readPosition
            } else {
                // The write position has looped around
                return size - readPosition + writePosition
            }
        }
    }
    
    convenience init(size: Int, maximumSize: Int) {
        self.init(size: size)
        self.maximumSize = maximumSize
    }
    
    init(size: Int) {
        self.size = size
        self.maximumSize = size // default to no expansion
        self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
    }
    
    func fill(with data: Data) -> Bool {
        return data.withUnsafeBytes {
            fill(with: $0, length: data.count)
        }
    }
    
    func fill(with bytes: UnsafeRawPointer, length: Int) -> Bool {
        return lock.synchronizedResult {
            // Make sure there is space
            if freeSpace > length {
                let bytesUntilEnd = size - writePosition
                if length > bytesUntilEnd {
                    // Split it between the end and beginning
                    memcpy(buffer + writePosition, bytes, bytesUntilEnd)
                    memcpy(buffer, bytes + bytesUntilEnd, length - bytesUntilEnd)
                } else {
                    // Just copy in the bytes
                    memcpy(buffer + writePosition, bytes, length);
                }
                
                advanceWritePosition(length: length)
                return true
            } else if size < maximumSize {
                // Expand the buffer and try to fill it again
                if expand() {
                    return fill(with: bytes, length: length)
                }
            }
            
            return false
        }
    }
    
    func drain(into bytes: UnsafeMutableRawPointer, length: Int) -> Int {
        return lock.synchronizedResult {
            let readLength = filledSpace >= length ? length : filledSpace
            if readLength > 0 {
                let bytesUntilEnd = size - readPosition
                if readLength > bytesUntilEnd {
                    // Split it between the end and beginning
                    memcpy(bytes, buffer + readPosition, bytesUntilEnd)
                    memcpy(bytes + bytesUntilEnd, buffer, readLength - bytesUntilEnd)
                } else {
                    // Just copy in the bytes
                    memcpy(bytes, buffer + readPosition, readLength)
                }
                
                advanceReadPosition(length: readLength)
            }
            return readLength
        }
    }
    
    func drainData(length: Int) -> Data {
        let dataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        let readLength = drain(into: dataBuffer, length: length)
        let data = Data(bytes: dataBuffer, count: readLength)
        dataBuffer.deinitialize()
        dataBuffer.deallocate(capacity: length)
        return data
    }
    
    
    func hasSpace(length: Int) -> Bool {
        return freeSpace >= length
    }
    
    func reset() {
        lock.synchronized {
            readPosition = 0
            writePosition = 0
        }
    }
    
    func expand() -> Bool {
        return lock.synchronizedResult {
            let additionalSize = Int(Double(size) * 0.25)
            return expand(additionalSize: additionalSize)
        }
    }
    
    func expand(additionalSize: Int) -> Bool {
        return lock.synchronizedResult {
            // First try to expand the buffer
            let totalSize = size + additionalSize
            if let rawPointer = realloc(buffer, totalSize * MemoryLayout<UInt8>.size) {
                let tempBuffer = rawPointer.assumingMemoryBound(to: UInt8.self)
                
                // Drain all the bytes into the new buffer
                let filledSize = filledSpace
                _ = drain(into: tempBuffer, length: filledSize)
                buffer = tempBuffer
                
                // Adjust the read and write positions
                readPosition = 0
                writePosition = filledSize
                
                return true
            }
            return false
        }
    }
    
    fileprivate func advanceWritePosition(length: Int) {
        lock.synchronized {
            writePosition += length
            if writePosition >= size {
                writePosition = writePosition - size
            }
        }
    }
    
    fileprivate func advanceReadPosition(length: Int) {
        lock.synchronized {
            readPosition += length
            if readPosition >= size {
                readPosition = readPosition - size;
            }
        }
    }
}
