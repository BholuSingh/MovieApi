//
//  Endpoint.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

/// Defines everything needed to build a URLRequest.
/// Conform to this protocol for each API group (e.g. MovieEndpoint, SearchEndpoint).
protocol Endpoint {
    var baseURL: URL            { get }
    var path: String            { get }
    var method: HTTPMethod      { get }
    var headers: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data?             { get }
    var timeoutInterval: TimeInterval { get }

    /// Listed as a protocol requirement (not just an extension default) so that
    /// concrete types can override it — e.g. when the API uses a root-level path
    /// where appendingPathComponent would produce unexpected results.
    func urlRequest() throws -> URLRequest
}

// MARK: - Defaults
extension Endpoint {
    var timeoutInterval: TimeInterval { 30 }
    var headers: [String: String]?    { nil }
    var queryItems: [URLQueryItem]?   { nil }
    var body: Data?                   { nil }
}

// MARK: - URLRequest Builder
extension Endpoint {
    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidResponse
        }

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = body
        return request
    }
}
