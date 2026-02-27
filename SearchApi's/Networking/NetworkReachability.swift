//
//  NetworkReachability.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Network
import Foundation

/// Monitors live network connectivity using NWPathMonitor.
/// Posts a Notification on every status change so multiple
/// NetworkOperation instances can observe independently.
final class NetworkReachability {

    static let shared = NetworkReachability()

    /// Observers listen to this notification.
    /// userInfo key "isConnected" → Bool
    static let statusChangedNotification = Notification.Name("NetworkReachabilityStatusChanged")

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.searchapis.reachability", qos: .utility)

    /// Current connectivity state. Safe to read from any thread.
    private(set) var isConnected: Bool = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied

            // Only broadcast when status actually changes.
            guard connected != self.isConnected else { return }
            self.isConnected = connected

            NotificationCenter.default.post(
                name: NetworkReachability.statusChangedNotification,
                object: nil,
                userInfo: ["isConnected": connected]
            )
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
