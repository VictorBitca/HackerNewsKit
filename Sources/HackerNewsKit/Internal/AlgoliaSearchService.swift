import Foundation

final class AlgoliaAPI {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    private struct SearchResultsFeed: Codable {
        let hits: [SearchResult]
    }

    private struct SearchResult: Codable {
        let title: String
        let url: String?
        let author: String
        let points: Int
        let commentsCount: Int?
        let createdAt: Int
        let relevancyScore: Int?
        let objectID: String
        
        enum CodingKeys: String, CodingKey {
            case title
            case url
            case author
            case points
            case commentsCount = "num_comments"
            case createdAt = "created_at_i"
            case relevancyScore = "relevancy_score"
            case objectID
        }
    }

    public func searchIDs(query: String) async throws -> [Int] {
        let urlString = "https://hn.algolia.com/api/v1/search?query=\(query.urlEncoded())&tags=story&page=0&hitsPerPage=100"
        guard let url = URL(string: urlString) else { throw "Failed to compose URL for query \(query)" }
        
        let (data, _) = try await session.data(for: URLRequest(url: url))
        let searchResult = try decoder.decode(SearchResultsFeed.self, from: data)
        
        return searchResult.hits.compactMap { Int($0.objectID) }
    }
}
