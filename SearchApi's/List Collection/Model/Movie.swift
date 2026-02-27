//
//  Movie.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

// MARK: - Movie Detail

/// Full movie detail returned by OMDB's `?i=` (by IMDb ID) endpoint.
/// Used by DetailsViewController.
struct Movie: Decodable {
    let title: String
    let year: String
    let released: String
    let runtime: String
    let actors: String
    let plot: String
    let poster: String
    let ratings: [Rating]
    let imdbID: String
    let response: String

    enum CodingKeys: String, CodingKey {
        case title    = "Title"
        case year     = "Year"
        case released = "Released"
        case runtime  = "Runtime"
        case actors   = "Actors"
        case plot     = "Plot"
        case poster   = "Poster"
        case ratings  = "Ratings"
        case imdbID   = "imdbID"
        case response = "Response"
    }

    /// Returns a valid poster URL, or nil when OMDB returns "N/A".
    var posterURL: URL? {
        poster == "N/A" ? nil : URL(string: poster)
    }
}

// MARK: - Rating

/// A single rating entry from one review source (IMDb, Rotten Tomatoes, etc.).
struct Rating: Decodable {
    let source: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case source = "Source"
        case value  = "Value"
    }
}
