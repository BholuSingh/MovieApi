//
//  NetworkError.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

enum NetworkError: Error {
    case noNetwork                  // Device is offline
    case timeout                    // Request timed out
    case badRequest                 // 400
    case unauthorized               // 401
    case forbidden                  // 403
    case notFound                   // 404
    case serverError(Int)           // 5xx
    case decodingFailed(Error)      // JSONDecoder failure
    case invalidResponse            // Non-HTTP response or nil data
    case cancelled                  // Explicitly cancelled
    case maxRetriesExceeded         // Failed after 3 attempts
    case unknown(Error)             // Catch-all
}

// MARK: - User-Facing Messages
extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noNetwork:               return "No internet connection. Please check your network and try again."
        case .timeout:                 return "The request timed out. Please try again."
        case .badRequest:              return "Bad request. Please check your input."
        case .unauthorized:            return "You are not authorised to perform this action."
        case .forbidden:               return "Access to this resource is forbidden."
        case .notFound:                return "The requested resource was not found."
        case .serverError(let code):   return "Server error (\(code)). Please try again later."
        case .decodingFailed:          return "Failed to process the server response."
        case .invalidResponse:         return "Received an invalid response from the server."
        case .cancelled:               return "The request was cancelled."
        case .maxRetriesExceeded:      return "The request failed after multiple attempts."
        case .unknown(let error):      return error.localizedDescription
        }
    }
}

// MARK: - Retry Policy
extension NetworkError {
    /// Only 5xx and timeouts are worth retrying.
    /// 4xx errors are client-side mistakes — retrying won't help.
    var isRetriable: Bool {
        switch self {
        case .timeout, .serverError: return true
        default:                     return false
        }
    }
}

// MARK: - URLError Mapping
extension NetworkError {
    static func map(_ error: Error) -> NetworkError {
        guard let urlError = error as? URLError else {
            return .unknown(error)
        }
        switch urlError.code {
        case .timedOut:                             return .timeout
        case .notConnectedToInternet,
             .networkConnectionLost:               return .noNetwork
        case .cancelled:                            return .cancelled
        default:                                    return .unknown(urlError)
        }
    }
}
