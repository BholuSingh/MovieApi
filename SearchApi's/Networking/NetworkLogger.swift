//
//  NetworkLogger.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation
import OSLog

/// Logs network activity to the Xcode/Console debug stream.
/// All output is compiled away in Release builds via #if DEBUG.
final class NetworkLogger {

    private static let logger = Logger(subsystem: "com.searchapis", category: "Network")

    // MARK: - Request
    static func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let url    = request.url?.absoluteString ?? "nil"
        logger.debug("→ \(method) \(url)")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("  Headers: \(headers)")
        }
        if let body = request.httpBody, let text = String(data: body, encoding: .utf8) {
            logger.debug("  Body: \(text)")
        }
        #endif
    }

    // MARK: - Response
    static func logResponse(_ response: URLResponse?, data: Data?, error: Error?) {
        #if DEBUG
        if let http = response as? HTTPURLResponse {
            let url    = http.url?.absoluteString ?? "nil"
            let status = http.statusCode
            logger.debug("← \(status) \(url)")
        }
        if let data, let text = String(data: data, encoding: .utf8) {
            logger.debug("  Body: \(text)")
        }
        if let error {
            logger.error("  Error: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - General
    static func log(_ message: String) {
        #if DEBUG
        logger.debug("\(message)")
        #endif
    }
}
