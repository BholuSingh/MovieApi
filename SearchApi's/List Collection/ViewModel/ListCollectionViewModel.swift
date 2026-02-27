//
//  ListCollectionViewModel.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation
import UIKit

// MARK: - Delegate

protocol ListCollectionViewModelDelegate: AnyObject {
    /// Called when the first page starts loading — show a spinner.
    func viewModelDidStartLoading()

    /// Called after the first page loads — reload the entire collection view.
    func viewModelDidReloadData()

    /// Called after a subsequent page loads — insert only the new index paths
    /// so existing cells don't flash.
    func viewModelDidLoadMore(at indexPaths: [IndexPath])

    /// Called on any network or decoding failure.
    func viewModelDidFail(with error: NetworkError)
}

// MARK: - ViewModel

final class ListCollectionViewModel {

    // MARK: - Public State

    /// All loaded movies. Append-only — never replaced after the first page.
    private(set) var movies: [MovieSummary] = []

    /// True while a page request is in-flight — prevents duplicate fetches.
    private(set) var isFetching = false

    /// True when there are more pages the user hasn't loaded yet.
    var hasMorePages: Bool { movies.count < totalResults }

    weak var delegate: ListCollectionViewModelDelegate?

    // MARK: - Private State

    private var currentPage  = 1
    private var totalResults = 0
    private var currentQuery = "Marvel"     // default query shown on first launch
    private var cancellable: NetworkCancellable?

    // MARK: - Public API

    /// Resets state and starts a fresh search.
    /// Fires delegate.viewModelDidStartLoading then viewModelDidReloadData.
    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Cancel any in-flight request before resetting state.
        // Without this, a slow previous response arriving after reset
        // would overwrite movies with stale results.
        cancellable?.cancel()
        isFetching    = false
        currentQuery  = query
        currentPage   = 1
        totalResults  = 0
        movies        = []
        fetchMovies(isFirstPage: true)
    }

    /// Loads the initial data using the default query.
    func loadInitialData() {
        fetchMovies(isFirstPage: true)
    }

    /// Appends the next page of results.
    /// No-ops when already fetching or no more pages remain.
    func fetchNextPage() {
        guard hasMorePages, !isFetching else { return }
        currentPage += 1
        fetchMovies(isFirstPage: false)
    }

    /// Cancels the current in-flight request (called from viewDidDisappear etc.)
    func cancelFetch() {
        cancellable?.cancel()
        isFetching = false
    }

    // MARK: - Private

    private func fetchMovies(isFirstPage: Bool) {
        guard !isFetching else { return }
        isFetching = true

        if isFirstPage {
            delegate?.viewModelDidStartLoading()
        }

        cancellable = NetworkManager.shared.request(
            MovieEndpoint.search(query: currentQuery, page: currentPage),
            responseType: MovieSearchResponse.self
        ) { [weak self] result in
            guard let self else { return }
            self.isFetching = false

            switch result {
            case .success(let response):
                // OMDB signals "no results" via Response = "False"
                guard response.response == "True" else {
                    self.delegate?.viewModelDidFail(with: .invalidResponse)
                    return
                }

                self.totalResults = response.totalResultsCount

                if isFirstPage {
                    self.movies = response.search
                    self.delegate?.viewModelDidReloadData()
                } else {
                    let startIndex  = self.movies.count
                    self.movies    += response.search
                    let newPaths    = (startIndex ..< self.movies.count)
                        .map { IndexPath(item: $0, section: 0) }
                    self.delegate?.viewModelDidLoadMore(at: newPaths)
                }

            case .failure(let error):
                // Roll back the page number so the user can retry.
                if !isFirstPage { self.currentPage -= 1 }
                self.delegate?.viewModelDidFail(with: error)
            }
        }
    }
}
