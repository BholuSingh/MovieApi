//
//  ImageCache.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import UIKit

/// Thread-safe image cache backed by NSCache.
/// NSCache itself is thread-safe, so no additional locking is needed here.
///
/// - Automatically clears all cached images on a memory warning.
/// - Cost per entry is the actual decoded byte footprint of the image,
///   so `totalCostLimit` maps directly to real RAM usage.
final class ImageCache {

    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Sane defaults — tune via configure() if needed.
        cache.countLimit       = 100              // max 100 images
        cache.totalCostLimit   = 50 * 1024 * 1024 // 50 MB

        // Drop everything the moment the OS is under memory pressure.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearAll),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Read / Write

    /// Returns the cached image for a URL, or nil if not cached.
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    /// Stores an image in the cache, keyed by URL.
    /// Cost is the decoded byte size of the image so the cost limit
    /// reflects real memory usage rather than an arbitrary number.
    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: image.decodedByteSize)
    }

    // MARK: - Eviction

    /// Removes the cached image for a specific URL.
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }

    /// Removes all cached images.
    @objc func clearAll() {
        cache.removeAllObjects()
    }

    // MARK: - Configuration

    /// Call once at app launch to override the defaults.
    /// - Parameters:
    ///   - countLimit:        Maximum number of images to hold.
    ///   - totalCostLimitMB:  Maximum total memory footprint in megabytes.
    func configure(countLimit: Int, totalCostLimitMB: Int) {
        cache.countLimit     = countLimit
        cache.totalCostLimit = totalCostLimitMB * 1024 * 1024
    }
}

// MARK: - Decoded Byte Size

private extension UIImage {
    /// Actual bytes the decoded bitmap occupies in RAM.
    /// bytesPerRow × height gives the true memory footprint.
    var decodedByteSize: Int {
        guard let cg = cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }
}
