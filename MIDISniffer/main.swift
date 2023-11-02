//
//  main.swift
//  MIDISniffer
//
//  Created by Chris on 02.11.23.
//

import Foundation

let deviceName = "Moog Grandmother"

do {
    let sniffer = try MIDISniffer(name: deviceName)
    sniffer.rxCallback = { data in
        NSLog(data.hexString)
    }
    NSLog("Listening for MIDI data from '%@'...", deviceName)
    RunLoop.main.run()
}
catch {
    NSLog(error.localizedDescription)
}
