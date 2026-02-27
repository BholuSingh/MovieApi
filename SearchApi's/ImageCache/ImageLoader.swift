//
//  ImageLoader.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import UIKit

// MARK: - Cancellable Token

/// Returned by every loadImage call.
/// Call cancel() to abort the load and remove the completion handler.
protocol ImageLoadCancellable {
    func cancel()
}

// MARK: - ImageLoader

/// Loads images from remote URLs with:
///  - Cache-first lookup (returns immediately if already cached)
///  - Deduplication: if the same URL is already downloading, the new
///    completion is queued behind the active download — no duplicate requests
///  - Per-request cancellation: cancelling a token removes its completion;
///    if it was the last pending completion for a URL the download is also cancelled
///  - All completions are dispatched on the main thread
final class ImageLoader {

    static let shared = ImageLoader()

    // MARK: - Private State

    private let session: URLSession

    /// Protects activeTasks and pendingCompletions from concurrent access.
    private let lock = NSLock()

    /// One active URLSessionDataTask per URL.
    private var activeTasks: [URL: URLSessionDataTask] = [:]

    /// Queued completions per URL: token → handler.
    /// Multiple callers can wait for the same URL without triggering extra downloads.
    private var pendingCompletions: [URL: [UUID: (UIImage?) -> Void]] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = nil // ImageCache manages caching — disable URLCache
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Loads an image from `url`, hitting the cache before the network.
    ///
    /// - Parameters:
    ///   - url:        Remote image URL.
    ///   - completion: Called on the main thread with the image, or nil on failure.
    /// - Returns: A token you can cancel at any time.
    @discardableResult
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> ImageLoadCancellable {

        // ── Cache hit: return immediately, no token needed ──────────────────
        if let cached = ImageCache.shared.image(for: url) {
            DispatchQueue.main.async { completion(cached) }
            return ImageLoadToken(id: UUID()) { }
        }

        // ── Cache miss: enqueue completion ───────────────────────────────────
        let token = UUID()

        lock.lock()
        let alreadyDownloading = pendingCompletions[url] != nil
        pendingCompletions[url, default: [:]][token] = completion
        lock.unlock()

        // Only start a new download if one isn't already running for this URL.
        if !alreadyDownloading {
            startDownload(for: url)
        }

        return ImageLoadToken(id: token) { [weak self] in
            self?.cancel(token: token, for: url)
        }
    }

    /// Cancels every in-flight download and clears all pending completions.
    func cancelAll() {
        lock.lock()
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        pendingCompletions.removeAll()
        lock.unlock()
    }

    // MARK: - Download

    private func startDownload(for url: URL) {
        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }

            // Decode and cache only if we got valid image data.
            let image: UIImage? = data.flatMap { UIImage(data: $0) }
            if let image {
                ImageCache.shared.store(image, for: url)
            }

            // Collect and remove all waiting completions atomically.
            self.lock.lock()
            let completions = self.pendingCompletions.removeValue(forKey: url)
            self.activeTasks.removeValue(forKey: url)
            self.lock.unlock()

            DispatchQueue.main.async {
                completions?.values.forEach { $0(image) }
            }
        }

        lock.lock()
        activeTasks[url] = task
        lock.unlock()

        task.resume()
    }

    // MARK: - Cancel

    private func cancel(token: UUID, for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        pendingCompletions[url]?.removeValue(forKey: token)

        // If there are no more waiters for this URL, cancel the download too.
        if pendingCompletions[url]?.isEmpty == true {
            activeTasks[url]?.cancel()
            activeTasks.removeValue(forKey: url)
            pendingCompletions.removeValue(forKey: url)
        }
    }
}

// MARK: - Token (private implementation detail)

private struct ImageLoadToken: ImageLoadCancellable {
    let id: UUID
    private let cancelAction: () -> Void

    init(id: UUID, cancel: @escaping () -> Void) {
        self.id           = id
        self.cancelAction = cancel
    }

    func cancel() { cancelAction() }
}
