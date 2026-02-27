//
//  MovieSearchResponse.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

// MARK: - Search Response

/// Top-level response from OMDB's `?s=` (search) endpoint.
struct MovieSearchResponse: Decodable {
    let search: [MovieSummary]
    let totalResults: String
    let response: String

    enum CodingKeys: String, CodingKey {
        case search       = "Search"
        case totalResults = "totalResults"
        case response     = "Response"
    }

    /// Convenience: parsed total as Int (OMDB returns it as a String).
    var totalResultsCount: Int { Int(totalResults) ?? 0 }
}

// MARK: - Movie Summary

/// One item inside the search results array.
/// Used to populate `ListCollectionCell` (poster + title only).
struct MovieSummary: Decodable {
    let title: String
    let year: String
    let imdbID: String
    let type: String
    let poster: String

    enum CodingKeys: String, CodingKey {
        case title  = "Title"
        case year   = "Year"
        case imdbID = "imdbID"
        case type   = "Type"
        case poster = "Poster"
    }

    /// Returns a valid URL for the poster, or nil when OMDB returns "N/A".
    var posterURL: URL? {
        poster == "N/A" ? nil : URL(string: poster)
    }
}
