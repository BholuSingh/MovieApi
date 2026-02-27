//
//  NetworkOperation.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

typealias NetworkCompletion<T: Decodable> = (Result<T, NetworkError>) -> Void

/// An asynchronous Operation that:
///  - Executes a single URLRequest on a provided URLSession
///  - Retries up to `maxRetries` times with exponential backoff (1s → 2s → 4s)
///    only for retriable errors (5xx, timeout) — never for 4xx
///  - Holds itself (stays in .executing) when the network drops mid-call,
///    and automatically resumes when connectivity is restored
///  - Can be cancelled at any point via cancel(), which propagates to the URLSessionDataTask
final class NetworkOperation<T: Decodable>: Operation, @unchecked Sendable {

    // MARK: - Async Operation State (KVO-compliant)

    private enum State: String {
        case ready     = "isReady"
        case executing = "isExecuting"
        case finished  = "isFinished"
    }

    private var _state: State = .ready

    /// Lock exclusively for _state. Keep it narrow — never call back into
    /// self while holding this lock to avoid deadlocks.
    private let stateLock = NSLock()

    private var state: State {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _state
        }
        set {
            // FIX: read the old value through the getter (which holds the lock)
            // rather than reading _state directly — eliminates the data race
            // in the setter where _state was previously read without the lock.
            let old = state.rawValue
            let new = newValue.rawValue
            willChangeValue(forKey: old)
            willChangeValue(forKey: new)
            stateLock.lock()
            _state = newValue
            stateLock.unlock()
            didChangeValue(forKey: new)
            didChangeValue(forKey: old)
        }
    }

    override var isReady: Bool      { state == .ready && super.isReady }
    override var isExecuting: Bool  { state == .executing }
    override var isFinished: Bool   { state == .finished }
    override var isAsynchronous: Bool { true }

    // MARK: - Properties

    private let urlRequest: URLRequest
    private let session: URLSession
    private let maxRetries: Int
    private let completion: NetworkCompletion<T>

    /// Lock for mutable resources accessed from multiple threads:
    /// task, retryCount, isObservingReachability.
    private let resourceLock = NSLock()

    private var task: URLSessionDataTask?
    private var retryCount = 0
    private var isObservingReachability = false

    // MARK: - Init

    init(
        request: URLRequest,
        session: URLSession,
        maxRetries: Int = 3,
        completion: @escaping NetworkCompletion<T>
    ) {
        self.urlRequest    = request
        self.session       = session
        self.maxRetries    = maxRetries
        self.completion    = completion
    }

    // MARK: - Operation Lifecycle

    override func start() {
        guard !isCancelled else {
            finish(with: .failure(.cancelled))
            return
        }
        state = .executing
        execute()
    }

    // MARK: - Execution

    private func execute() {
        guard !isCancelled else {
            finish(with: .failure(.cancelled))
            return
        }

        guard NetworkReachability.shared.isConnected else {
            hold()
            return
        }

        NetworkLogger.logRequest(urlRequest)

        // FIX: store the task under the lock so cancel() can safely access it
        // from a concurrent thread without a data race.
        let newTask = session.dataTask(with: urlRequest) { [weak self] data, response, error in
            self?.handleResponse(data: data, response: response, error: error)
        }
        resourceLock.lock()
        task = newTask
        resourceLock.unlock()

        newTask.resume()
    }

    // MARK: - Response Handling

    private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        guard !isCancelled else {
            finish(with: .failure(.cancelled))
            return
        }

        NetworkLogger.logResponse(response, data: data, error: error)

        // Network dropped mid-call → hold and wait for restoration.
        if let urlError = error as? URLError,
           urlError.code == .networkConnectionLost || urlError.code == .notConnectedToInternet {
            hold()
            return
        }

        if let error {
            handleError(NetworkError.map(error))
            return
        }

        guard let http = response as? HTTPURLResponse else {
            finish(with: .failure(.invalidResponse))
            return
        }

        switch http.statusCode {
        case 200...299:
            decode(data)

        // 4xx — client errors, never retry.
        case 400:   finish(with: .failure(.badRequest))
        case 401:   finish(with: .failure(.unauthorized))
        case 403:   finish(with: .failure(.forbidden))
        case 404:   finish(with: .failure(.notFound))

        // 5xx — server errors, retriable.
        case 500...599:
            handleError(.serverError(http.statusCode))

        default:
            finish(with: .failure(.invalidResponse))
        }
    }

    // MARK: - Retry (exponential backoff: 1s, 2s, 4s)

    private func handleError(_ error: NetworkError) {
        resourceLock.lock()
        let count = retryCount
        if error.isRetriable && count < maxRetries {
            retryCount += 1
            resourceLock.unlock()
            let delay = pow(2.0, Double(count))
            NetworkLogger.log("🔄 Retry \(count + 1)/\(maxRetries) in \(Int(delay))s — \(urlRequest.url?.absoluteString ?? "")")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.execute()
            }
        } else {
            resourceLock.unlock()
            let final: NetworkError = count >= maxRetries ? .maxRetriesExceeded : error
            finish(with: .failure(final))
        }
    }

    // MARK: - Decode

    private func decode(_ data: Data?) {
        guard let data else {
            finish(with: .failure(.invalidResponse))
            return
        }
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            finish(with: .success(decoded))
        } catch {
            finish(with: .failure(.decodingFailed(error)))
        }
    }

    // MARK: - Hold (network lost mid-call or before call)

    private func hold() {
        resourceLock.lock()
        guard !isObservingReachability else {
            resourceLock.unlock()
            return
        }
        isObservingReachability = true
        resourceLock.unlock()

        NetworkLogger.log("⏸ Request held — awaiting network: \(urlRequest.url?.absoluteString ?? "")")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged(_:)),
            name: NetworkReachability.statusChangedNotification,
            object: nil
        )
    }

    @objc private func networkStatusChanged(_ notification: Notification) {
        guard
            let isConnected = notification.userInfo?["isConnected"] as? Bool,
            isConnected
        else { return }

        stopObservingReachability()

        guard !isCancelled else {
            finish(with: .failure(.cancelled))
            return
        }

        NetworkLogger.log("▶ Network restored — resuming: \(urlRequest.url?.absoluteString ?? "")")
        execute()
    }

    private func stopObservingReachability() {
        resourceLock.lock()
        guard isObservingReachability else {
            resourceLock.unlock()
            return
        }
        isObservingReachability = false
        resourceLock.unlock()

        NotificationCenter.default.removeObserver(
            self,
            name: NetworkReachability.statusChangedNotification,
            object: nil
        )
    }

    // MARK: - Finish

    private func finish(with result: Result<T, NetworkError>) {
        guard isExecuting else { return }
        stopObservingReachability()

        // FIX 1: transition to .finished BEFORE dispatching the completion
        // so that no concurrent call to finish() or cancel() can pass
        // the isExecuting guard while the completion is in-flight.
        //
        // FIX 2: capture `completion` by value (not via weak self) so the
        // closure is guaranteed to fire even if the OperationQueue releases
        // its reference to this operation before the main queue runs the block.
        state = .finished
        let comp = completion
        DispatchQueue.main.async {
            comp(result)
        }
    }

    // MARK: - Cancel

    override func cancel() {
        super.cancel()

        // FIX: read and nil out `task` under the lock to avoid a data race
        // with execute() assigning a new task on a concurrent thread.
        resourceLock.lock()
        let currentTask = task
        task = nil
        resourceLock.unlock()

        currentTask?.cancel()
        stopObservingReachability()

        if isExecuting {
            finish(with: .failure(.cancelled))
        }
    }
}
