//
//  OSLogs.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import OSLog

class OSLogs {
    private let logger = Logger(subsystem: "com.abc", category: "Image SynchUP")
    private let signposter = OSSignposter(subsystem: "com.abc", category: "Image SynchUP")

    func syncImages() {
        let id = signposter.makeSignpostID(from: self)
        let state = signposter.beginInterval("Image SynchUP", id: id, "Syncing image data")
        // Perform image sync work here
        signposter.endInterval("Image SynchUP", state)
    }
}
