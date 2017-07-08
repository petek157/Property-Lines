//
//  SessionController.swift
//  Property Lines
//
//  Created by Peter Koruga on 7/8/17.
//  Copyright © 2017 P3 Media. All rights reserved.
//

import UIKit
import ExternalAccessory

class SessionController: NSObject, EAAccessoryDelegate, StreamDelegate {
    
    static let sharedController = SessionController()
    var _accessory: EAAccessory?
    var _session: EASession?
    var _protocolString: String?
    var _writeData: Data?
    var _readData: Data?
    var _dataAsString: NSString?
    
    // MARK: Controller Setup
    
    func setupController(forAccessory accessory: EAAccessory, withProtocolString protocolString: String) {
        _accessory = accessory
        _protocolString = protocolString
    }
    
    // MARK: Opening & Closing Sessions
    
    func openSession() -> Bool {
        _accessory?.delegate = self
        _session = EASession(accessory: _accessory!, forProtocol: _protocolString!)
        
        if _session != nil {
            _session?.inputStream?.delegate = self
            _session?.inputStream?.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
            _session?.inputStream?.open()
            
            _session?.outputStream?.delegate = self
            _session?.outputStream?.schedule(in: RunLoop.current, forMode: .defaultRunLoopMode)
            _session?.outputStream?.open()
        } else {
            print("Failed to create session")
        }
        
        return _session != nil
    }
    
    func closeSession() {
        
        _session?.inputStream?.close()
        _session?.inputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        _session?.inputStream?.delegate = nil
        
        _session?.outputStream?.close()
        _session?.outputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        _session?.outputStream?.delegate = nil
        
        _session = nil
        _writeData = nil
        _readData = nil
    }
    
    // MARK: Write & Read Data
    
    func writeData(data: Data) {
        if _writeData == nil {
            _writeData = Data()
        }
        
        _writeData?.append(data)
        self.writeData()
    }
    
    func readData(bytesToRead: Int) -> Data {
        
        var data: Data?
        if _readData != nil {
            if _readData!.count >= bytesToRead {
                let range =  Range(0 ..< bytesToRead)
                data = _readData!.subdata(in: range)
                _readData?.replaceSubrange(range, with: nil)
            }
        }
        return data!
    }
    
    func readBytesAvailable() -> Int {
        return (_readData?.count)!
    }
    
    // MARK: - Helpers
    func updateReadData() {
        let bufferSize = 128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        while _session?.inputStream?.hasBytesAvailable == true {
            let bytesRead = _session?.inputStream?.read(&buffer, maxLength: bufferSize)
            if _readData == nil {
                _readData = Data()
            }
            _readData?.append(buffer, count: bytesRead!)
            _dataAsString = NSString(bytes: buffer, length: bytesRead!, encoding: String.Encoding.utf8.rawValue)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "BESessionDataReceivedNotification"), object: nil)
        }
    }
    
    private func writeData() {
        while (_session?.outputStream?.hasSpaceAvailable)! == true && _writeData!.count > 0 {
//            var buffer = [UInt8](repeating: 0, count: _writeData!.count)
//            _writeData?.getBytes(buffer, length: _writeData!.count)
            var buffer = [UInt8](_writeData!)
            var bytesWritten = _session?.outputStream?.write(&buffer, maxLength: _writeData!.count)
            if bytesWritten == -1 {
                print("Write Error")
                return
                
            } else if bytesWritten! > 0 {
                _writeData?.replaceSubrange(Range(0 ..< bytesWritten!), with: nil)
//                _writeData?.replaceBytesInRange(NSMakeRange(0, bytesWritten!), withBytes: nil, length: 0)
            }
        }
    }
    
    // MARK: - EAAcessoryDelegate
    
    func accessoryDidDisconnect(_ accessory: EAAccessory) {
        // Accessory diconnected from iOS, updating accordingly
    }
    
    // MARK: - NSStreamDelegateEventExtensions
    
    func stream(aStream: Stream, handleEvent eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            break
        case Stream.Event.hasBytesAvailable:
            // Read Data
            updateReadData()
            break
        case Stream.Event.hasSpaceAvailable:
            // Write Data
            self.writeData()
            break
        case Stream.Event.errorOccurred:
            break
        case Stream.Event.endEncountered:
            break
            
        default:
            break
        }
    }
}
