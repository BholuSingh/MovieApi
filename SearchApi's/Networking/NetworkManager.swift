//
//  NetworkManager.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

// MARK: - Cancellable Token
//
// Returned by every request() call so callers can cancel that specific request.
// Store the token and call cancel() whenever you want to abort (e.g. viewDidDisappear).

protocol NetworkCancellable {
    func cancel()
}

extension NetworkOperation: NetworkCancellable {}

// MARK: - Request Priority

enum RequestPriority {
    case high, normal, low

    var queuePriority: Operation.QueuePriority {
        switch self {
        case .high:   return .high
        case .normal: return .normal
        case .low:    return .low
        }
    }
}

// MARK: - NetworkManager

/// Central entry point for all network calls.
///
/// Usage:
///   let token = NetworkManager.shared.request(
///       MovieEndpoint.search(query: "Batman"),
///       responseType: MovieResponse.self
///   ) { result in
///       switch result {
///       case .success(let movies): ...
///       case .failure(let error):  ...
///       }
///   }
///   // To cancel:
///   token?.cancel()

final class NetworkManager {

    static let shared = NetworkManager()

    // MARK: - Private

    private let session: URLSession
    private let operationQueue: OperationQueue

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30   // seconds per request
        config.timeoutIntervalForResource = 60   // total resource timeout
        self.session = URLSession(configuration: config)

        self.operationQueue = OperationQueue()
        self.operationQueue.name = "com.searchapis.networkQueue"
        // Allow up to 4 concurrent requests. Held operations (network-down)
        // still occupy a slot — new requests queue behind them until network
        // is restored and slots free up, which is intentional.
        self.operationQueue.maxConcurrentOperationCount = 4
        self.operationQueue.qualityOfService = .userInitiated
    }

    // MARK: - Public API

    /// Fires a network request and returns a cancellable token.
    ///
    /// - Parameters:
    ///   - endpoint:     Anything conforming to `Endpoint` (URL, method, headers, body).
    ///   - responseType: The `Decodable` type to decode the response into.
    ///   - priority:     Relative priority in the queue (.high / .normal / .low).
    ///   - completion:   Called on the **main thread** with success or failure.
    /// - Returns: A `NetworkCancellable` token. Store it; call `.cancel()` to abort.
    @discardableResult
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        priority: RequestPriority = .normal,
        completion: @escaping NetworkCompletion<T>
    ) -> NetworkCancellable? {

        let urlRequest: URLRequest
        do {
            urlRequest = try endpoint.urlRequest()
        } catch {
            completion(.failure(.invalidResponse))
            return nil
        }

        let operation = NetworkOperation<T>(
            request: urlRequest,
            session: session,
            completion: completion
        )
        operation.queuePriority = priority.queuePriority

        operationQueue.addOperation(operation)
        return operation
    }

    // MARK: - Queue Control

    /// Cancels every pending and in-flight request.
    /// Useful on logout or when leaving a screen with many requests.
    func cancelAll() {
        operationQueue.cancelAllOperations()
        NetworkLogger.log("🚫 All network operations cancelled")
    }

    /// Suspends the queue — queued operations will not start until resume() is called.
    /// Already-executing operations continue to run.
    func suspend() {
        operationQueue.isSuspended = true
        NetworkLogger.log("⏸ Network queue suspended")
    }

    /// Resumes a suspended queue.
    func resume() {
        operationQueue.isSuspended = false
        NetworkLogger.log("▶ Network queue resumed")
    }
}
