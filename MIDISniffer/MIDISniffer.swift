//
//  MIDISniffer.swift
//  MIDISniffer
//
//  Created by Chris on 02.11.23.
//

import Foundation
import CoreMIDI

final class MIDISniffer {
    private static let identifier = "com.MIDISniffer.MIDIDestination"
    
    private static var inputDevices: [Device] {
        var devices = [Device]()
        for idx in 0 ..< MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(idx)
            if let device = getDevice(for: endpoint) {
                devices.append(device)
            }
        }
        return devices
    }
    
    private class func getDevice(for endpoint: MIDIEndpointRef) -> Device? {
        var propUID = MIDIUniqueID(0)
        var propName: Unmanaged<CFString>?
        guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &propUID) == noErr else { return nil }
        guard propUID != 0 else { return nil }
        let device: Device
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &propName) == noErr, let cfName = propName?.takeRetainedValue() {
            device = Device(uid: propUID, name: cfName as String)
        } else {
            device = Device(uid: propUID, name: propUID.description)
        }
        return device
    }
    
    
    enum Error: Swift.Error {
        case deviceNotFound(String)
        case sourceNotFound
        case connectSourceFailed
        case createClientFailed
        case createDestinationFailed
        case createInputPortFailed
    }
    
    typealias Device = (uid: Int32, name: String)
    typealias RXCallback = (Data) -> Void
    var rxCallback: RXCallback?
    
    private var midiClient = MIDIClientRef()
    private var midiInPort = MIDIPortRef()
    private var midiEndpoint = MIDIEndpointRef()
    
    
    init(name: String) throws {
        guard let inDev = MIDISniffer.inputDevices.first(where: { $0.name == name }) else { throw Error.deviceNotFound(name) }
        guard MIDIClientCreateWithBlock(MIDISniffer.identifier as CFString, &midiClient, nil) == noErr else { throw Error.createClientFailed }
        guard MIDIInputPortCreateWithProtocol(midiClient, "MIDI IN" as CFString, ._2_0, &midiInPort, midiReceiveBlock) == noErr else { throw Error.createInputPortFailed }
        try connectSource(device: inDev)
    }
    
    private func connectSource(device: Device) throws {
        var foundIdx: Int?
        for idx in 0 ..< MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(idx)
            var propUID = MIDIUniqueID(0)
            let _ = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &propUID)
            if propUID == device.uid {
                foundIdx = idx
                break
            }
        }
        guard let sourceIdx = foundIdx else { throw Error.sourceNotFound }
        let endpoint = MIDIGetSource(sourceIdx)
        guard MIDIPortConnectSource(midiInPort, endpoint, nil) == noErr else { throw Error.connectSourceFailed }
    }
    
    private func midiReceiveBlock(_ evtlist: UnsafePointer<MIDIEventList>, _ srcConnRefCon: UnsafeMutableRawPointer?) {
        for packet in evtlist.unsafeSequence() {
            let words = MIDIEventPacket.WordCollection(packet)
            let wordCount = packet.pointee.wordCount
            var wordIdx = 0
            while wordIdx < wordCount {
                let word = words[wordIdx]
                wordIdx += 1
                rxCallback?(word.data)
            }
        }
    }
}

fileprivate extension FixedWidthInteger {
    var bytes: [UInt8] { withUnsafeBytes(of: self.bigEndian, Array.init) }
    var data: Data { Data(self.bytes) }
}

extension Data {
    var hexString: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
