//
//  MovieEndpoint.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import Foundation

/// All OMDB API endpoints used in the app.
///
/// OMDB serves everything from the root path `/?` so this endpoint
/// overrides `urlRequest()` directly via URLComponents to avoid
/// the `appendingPathComponent` URL-encoding issues with root-level APIs.
enum MovieEndpoint: Endpoint {

    /// Paginated search — returns up to 10 results per page.
    case search(query: String, page: Int)

    /// Full detail for a single movie by its IMDb ID.
    case detail(imdbID: String)

    // MARK: - Endpoint Requirements (unused by urlRequest override)

    var baseURL: URL    { URL(string: "https://www.omdbapi.com")! }
    var path: String    { "/" }
    var method: HTTPMethod { .get }

    // MARK: - Query Items

    var queryItems: [URLQueryItem]? {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "apikey", value: MovieEndpoint.apiKey)
        ]
        switch self {
        case .search(let query, let page):
            items.append(URLQueryItem(name: "s",    value: query))
            items.append(URLQueryItem(name: "type", value: "movie"))
            items.append(URLQueryItem(name: "page", value: "\(page)"))

        case .detail(let imdbID):
            items.append(URLQueryItem(name: "i",    value: imdbID))
            items.append(URLQueryItem(name: "plot", value: "full"))
        }
        return items
    }

    // MARK: - URLRequest Override
    //
    // OMDB's root-level path `/` is incompatible with URL.appendingPathComponent,
    // so we build the request directly using URLComponents.

    func urlRequest() throws -> URLRequest {
        var components        = URLComponents()
        components.scheme     = "https"
        components.host       = "www.omdbapi.com"
        components.path       = "/"
        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Private

    private static let apiKey = "b4cf2df6"
}
