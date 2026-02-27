//
//  UIImageView+ImageLoader.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import UIKit

/// Adds one-line remote image loading to any UIImageView.
///
/// Usage:
///   imageView.setImage(from: url)
///   imageView.setImage(from: url, placeholder: UIImage(named: "placeholder"))
///
/// The previous in-flight load is automatically cancelled whenever
/// setImage(from:) is called again — safe to use inside UITableViewCell
/// and UICollectionViewCell which are frequently reused.
extension UIImageView {

    // MARK: - Public API

    /// Loads and displays the image at `url`.
    ///
    /// - Parameters:
    ///   - url:         Remote image URL.
    ///   - placeholder: Shown immediately while the download is in progress.
    ///                  Also shown if the download fails.
    func setImage(from url: URL, placeholder: UIImage? = nil) {
        // Show placeholder right away so the cell never looks blank.
        image = placeholder

        // Cancel any load still running from a previous reuse cycle.
        cancelImageLoad()

        let token = ImageLoader.shared.loadImage(from: url) { [weak self] downloaded in
            guard let self else { return }
            // Use downloaded image if we got one; fall back to placeholder.
            self.image = downloaded ?? placeholder
        }

        // Store the token so the next reuse (or explicit cancel) can stop it.
        activeImageToken = token
    }

    /// Cancels an in-flight load and clears the stored token.
    /// Call this from prepareForReuse() if you want explicit control.
    func cancelImageLoad() {
        activeImageToken?.cancel()
        activeImageToken = nil
    }

    // MARK: - Associated Token Storage

    private static var tokenKey: UInt8 = 0

    private var activeImageToken: ImageLoadCancellable? {
        get {
            objc_getAssociatedObject(self, &UIImageView.tokenKey) as? ImageLoadCancellable
        }
        set {
            objc_setAssociatedObject(
                self,
                &UIImageView.tokenKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
