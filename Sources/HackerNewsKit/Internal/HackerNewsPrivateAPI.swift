import Foundation
import SwiftSoup

/// Wraper that treats the `news.ycombinator.com` site as the an API for the unofficial private functions.
struct HackerNewsPrivateAPI {
    let loader = RateLimitedNetworkResourceLoader()
    
    func jobIDs() async throws -> [Int] {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/jobstories.json") else { throw "Invalid URL" }
        let data = try await loader.execute(request: URLRequest(url: url))
        return try JSONDecoder().decode([Int].self, from: data)
    }
    
    private func buildURL(path: String, queryItems: [String: String] = [:]) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "news.ycombinator.com"
        urlComponents.path = "/\(path)"
        
        if queryItems.count > 0 {
            urlComponents.queryItems = queryItems.map { (key, val) in  URLQueryItem(name: key, value: val) }
        }
        
        return urlComponents.url
    }
    
    /// The login token is stored in the HTTPCookieStorage, subsequest requests use whatever cookies are available for the requested domain.
    func login(username: String, password: String) async throws {
        guard let url = buildURL(path: "login", queryItems: ["acct": username, "pw": password]) else { throw "Bad URL" }
        
        let request = URLRequest(url: url)
        let data = try await loader.execute(request: request)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw "Bad login response"
        }
        if html.contains("Bad login") || html.contains("Create Account") {
            throw "Bad credentials"
        }
        if html.contains("recaptcha") {
            throw "Too many login attempts, try again later"
        }
        UserStorage.loggedInUser = username
    }
    
    // Favorite
    func favorite(id: Int) async throws {
        //https://news.ycombinator.com/fave?id=21860713&auth=fd64183e4d3ccf5a84b3629778436f2bb998e2ae
        guard UserStorage.isLoggedIn else {
            throw "Not logged in"
        }
        
        // https://news.ycombinator.com/item?id=21766886
        guard let url = buildURL(path: "item", queryItems: ["id": String(id)]) else {
            throw "Invalid URL"
        }
        
        let data = try await loader.load(url: url)
        
        guard let input = String(data: data, encoding: .utf8) else {
            throw "Failed to load item details"
        }
        
        let start = "fave?id=\(id)&amp;auth="
        let end = "\""
        
        guard let startIndex = input.indices(of: start).first else {
            throw "Failed to to find auth start index"
        }
        
        let mod = input.index(startIndex, offsetBy: start.count)
        let temp = String(input[mod..<input.endIndex])
        
        guard let endIndex = temp.indices(of: end).first else {
            throw "Failed to find end index"
        }
        
        let auth = String(temp[..<endIndex])
        
        guard let url = buildURL(path: "fave", queryItems: ["id": String(id), "auth" : auth]) else {
            throw "Bad URL"
        }
        
        let _ = try await loader.load(url: url)
    }
    
    func unfavorite(id: Int) async throws {
        // https://news.ycombinator.com/fave?id=21860713&un=t&auth=fd64183e4d3ccf5a84b3629778436f2bb998e2ae
        guard UserStorage.isLoggedIn else {
            throw "Not logged in"
        }
        
        // https://news.ycombinator.com/item?id=21766886
        guard let url = self.buildURL(path: "item", queryItems: ["id": String(id)]) else {
            throw "Invalid URL"
        }
        
        let data = try await loader.load(url: url)
        
        // Try to get the auth param
        guard let input = String(data: data, encoding: .utf8) else {
            throw "Failed to load item details"
        }
        
        let start = "fave?id=\(id)&amp;un=t&amp;auth="
        let end = "\""
        
        guard let startIndex = input.indices(of: start).first else {
            throw "Failed to to find auth start index"
        }
        
        let mod = input.index(startIndex, offsetBy: start.count)
        let temp = String(input[mod..<input.endIndex])
        
        guard let endIndex = temp.indices(of: end).first else {
            throw "Failed to find end index"
        }
        
        let auth = String(temp[..<endIndex])
        
        guard let url = buildURL(path: "fave", queryItems: ["id": String(id),
                                                            "un": "t",
                                                            "auth" : auth]) else {
            throw "Bad URL"
        }
        
        let _ = try await loader.load(url: url)
    }
    
    func upvote(id: Int) async throws {
        guard UserStorage.isLoggedIn else {
            throw "Not logged in"
        }
        
        // https://news.ycombinator.com/item?id=21766886
        guard let url = buildURL(path: "item", queryItems: ["id": String(id)]) else {
            throw "Invalid URL"
        }
        
        let data = try await loader.load(url: url)
        guard let input = String(data: data, encoding: .utf8) else {
            throw "Failed to get data"
        }
        
        let start = "vote?id=\(id)&amp;how=up&amp;auth="
        let end = "&amp;goto=item"
        
        guard let startIndex = input.indices(of: start).first else {
            throw "Failed to to find auth start index"
        }
        
        let mod = input.index(startIndex, offsetBy: start.count)
        let temp = String(input[mod..<input.endIndex])
        
        guard let endIndex = temp.indices(of: end).first else {
            throw "Failed to auth end index"
        }
        
        let auth = temp[..<endIndex]
        
        // https://news.ycombinator.com/vote?id=21766886&how=up&auth=5a94c93969c6f3b5ce70e749a52aa21caed5dd4d&goto=item%3Fid%3D21766886
        guard let url = buildURL(path: "vote", queryItems: ["id": String(id), "how": "up", "auth" : String(auth)]) else {
            throw "Bad URL"
        }
        
        let _ = try await loader.load(url: url)
    }
    
    func unvote(id: Int) async throws {
        guard UserStorage.isLoggedIn else {
            throw "Not logged in"
        }
        
        // https://news.ycombinator.com/item?id=21766886
        guard let url = buildURL(path: "item", queryItems: ["id": String(id)]) else {
            throw "Invalid URL"
        }
        
        let data = try await loader.load(url: url)
        guard let input = String(data: data, encoding: .utf8) else {
            throw "Failed to get data"
        }
        
        let start = "vote?id=\(id)&amp;how=un&amp;auth="
        let end = "&amp;goto=item"
        
        guard let startIndex = input.indices(of: start).first else {
            throw "Failed to to find auth start index"
        }
        
        let mod = input.index(startIndex, offsetBy: start.count)
        let temp = String(input[mod..<input.endIndex])
        
        guard let endIndex = temp.indices(of: end).first else {
            throw "Failed to auth end index"
        }
        
        let auth = temp[..<endIndex]
        
        // https://news.ycombinator.com/vote?id=21766886&how=up&auth=5a94c93969c6f3b5ce70e749a52aa21caed5dd4d&goto=item%3Fid%3D21766886
        guard let url = buildURL(path: "vote", queryItems: ["id": String(id), "how": "un", "auth" : String(auth)]) else {
            throw "Bad URL"
        }
        
        let _ = try await loader.load(url: url)
    }
    
    func postCommentReply(to id: Int, with text: String) async throws {
        // https://news.ycombinator.com/reply?id=21772716
        guard UserStorage.isLoggedIn else {
            throw "Not logged in"
        }
        
        guard let url = buildURL(path: "reply", queryItems: ["id" : String(id)]) else {
            throw "Bad URL"
        }
        
        let data = try await loader.load(url: url)
        
        guard let hmac = extractHMAC(data: data) else {
            throw "No HMAC"
        }
        
        try await reply(to: String(id), goto: nil, hmac: String(hmac), text: text)
    }
    
    func postStoryReply(to id: Int, goto: Int, with text: String) async throws {
        // https://news.ycombinator.com/item?id=21766886
        
        guard let url = self.buildURL(path: "item", queryItems: ["id" : String(id)]) else {
            throw "Bad URL"
        }
        
        let data = try await loader.load(url: url)
        
        guard let hmac = extractHMAC(data: data) else {
            throw "No HMAC"
        }
        
        try await reply(to: String(id), goto: String(goto), hmac: String(hmac), text: text)
    }
    
    private func extractHMAC(data: Data) -> String? {
        guard let input = String(data: data, encoding: .utf8) else {
            return nil
        }
        let start = "name=\"hmac\" value=\""
        let end = "\""
        
        guard let startIndex = input.indices(of: start).first else { return nil }
        let mod = input.index(startIndex, offsetBy: start.count)
        let temp = String(input[mod..<input.endIndex])
        
        guard let endIndex = temp.indices(of: end).first else { return nil }
        let hmac = temp[..<endIndex]
        
        return String(hmac)
    }
    
    private func reply(to ID: String, goto: String?, hmac: String, text: String) async throws {
        guard let url = buildURL(path: "comment") else {
            throw "Bad URL"
        }
        
        var parameters: [String: Any] = [
            "parent": ID,
            "hmac": hmac,
            "text": reply,
        ]
        
        if let goto = goto {
            parameters["goto"] = "item?id=\(goto)"
        }
        
        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.httpBody = parameters.percentEncoded()
        
        let resp = try await loader.execute(request: request)
        
        if let html = String(data: resp, encoding: .utf8) {
            if html.contains("posting too fast") {
                throw "Posting too fast"
            }
            
            if html.contains("Please confirm that this is your comment by submitting it one\n more time.") {
                throw "Some parameters are missing"
            }
        }
    }
}

// MARK: - Saved items

extension HackerNewsPrivateAPI {    
    func savedStoriesIDs(type: SaveType) throws -> AsyncStream<[Int]> {
        guard let user = UserStorage.loggedInUser else { throw "User not logged in" }
        
        return AsyncStream { continuation in
            @Sendable func request(for page: Int) -> URLRequest? {
                guard let url = buildURL(path: type.rawValue, queryItems: ["id": user, "p": "\(page)"]) else { return nil }
                return URLRequest(url: url)
            }
            
            @Sendable func load(page: Int) async {
                guard let request = request(for: page) else { return continuation.finish() }
                
                switch type {
                case .favorite:
                    guard let ids = try? await loadFavoriteIDs(request: request), ids.count > 0 else {
                        return continuation.finish()
                    }
                    
                    continuation.yield(ids)
                    
                    await load(page: page + 1)
                case .upvote:
                    guard let ids = try? await loadVotedIDs(request: request), ids.count > 0 else {
                        return continuation.finish()
                    }
                    
                    continuation.yield(ids)
                    
                    await load(page: page + 1)
                }
            }
            
            Task {
                await load(page: 1)
            }
        }
    }
    
    private func loadVotedIDs(request: URLRequest) async throws -> [Int] {
        func extractVotedStoryID(input: String) -> Int? {
            let start = "item?id="
            
            guard let startIndex = input.indices(of: start).first else {
                return nil
            }
            let mod = input.index(startIndex, offsetBy: start.count)
            let temp = String(input[mod..<input.endIndex])
            
            return Int(temp)
        }
        
        let data = try await loader.execute(request: request)
        guard let input = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Extract all the links elements
        let elements: Elements = try! SwiftSoup.parse(input).select("a")
        
        // Extract the unfavorite links
        return elements
            .array()
            .map { try? $0.attr("href") }
            .compactMap { $0 }
            .filter { $0.hasPrefix("item?id=") }
            .map(extractVotedStoryID)
            .compactMap { $0 }
            .uniqued()
    }

    // Loads the favorite story IDs
    private func loadFavoriteIDs(request: URLRequest) async throws -> [Int] {
        let data = try await loader.execute(request: request)
        guard let input = String(data: data, encoding: .utf8) else { throw "Invalid response" }

        // Extract all the links elements
        let maybeElements: Elements? = try SwiftSoup.parse(input).select("a")
        guard let elements = maybeElements else { throw "Failed to parse the response" }

        // Extract the unfavorite links
        let ids = elements
            .array()
            .filter { ((try? $0.text()) ?? "").contains("favorite") }
            .map { try? $0.attr("href") }
            .compactMap { $0 }
            .filter { $0.hasPrefix("fave?id=") }
            .map(self.extractStoryID)
            .compactMap { $0 }
            .uniqued()

        return ids
    }

    private func extractStoryID(input: String) -> Int? {
        let start = "fave?id="
        let end = "&un=t&auth="

        guard let startIndex = input.indices(of: start).first else {
            return nil
        }
        let mod = input.index(startIndex, offsetBy: start.count)
        let temp = String(input[mod..<input.endIndex])

        guard let endIndex = temp.indices(of: end).first else {
            return nil
        }

        let id = temp[..<endIndex]

        return Int(id)
    }
    
    func savedCommentsIDs(type: SaveType) throws -> AsyncStream<[(parentStoryID: Int, commentID: Int)]> {
        guard let user = UserStorage.loggedInUser else {
            throw "User not logged in"
        }
        
        return AsyncStream { continuation in
            @Sendable func request(for page: Int) -> URLRequest? {
                let queryItems = ["id": user, "p": "\(page)", "comments" : "t"]
                guard let url = buildURL(path: type.rawValue, queryItems: queryItems) else { return nil }
                return URLRequest(url: url)
            }
            
            @Sendable func load(page: Int) async {
                guard let request = request(for: page) else { return continuation.finish() }
                switch type {
                case .favorite:
                    guard let ids = try? await loadFavoriteIDPairs(request: request), ids.count > 0 else {
                        return continuation.finish()
                    }
                    
                    continuation.yield(ids)
            
                    await load(page: page + 1)
                case .upvote:
                    guard let ids = try? await loadVotedIDPairs(request: request), ids.count > 0 else {
                        return continuation.finish()
                    }
                    
                    continuation.yield(ids)
            
                    await load(page: page + 1)
                }
            }
            
            Task {
                await load(page: 1)
            }
        }
    }
    
    private func loadFavoriteIDPairs(request: URLRequest) async throws -> [(Int, Int)] {
        let data = try await loader.execute(request: request)
        
        guard let input = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Extract all the on story elements
        let onstoryElements: Elements? = try? SwiftSoup.parse(input).getElementsByClass("onstory")
        
        guard let storyElements = onstoryElements else {
            return []
        }
        
        let storyIds = storyElements.array()
            .map { try? $0.select("a[href]").array().first?.attr("href") }
            .compactMap { $0 }
            .filter { $0.hasPrefix("item?id=") }
            .map(self.extractCommentParentStoryID)
            .compactMap { $0 }
        
        // Extract all the links elements
        let commentElements: Elements = try! SwiftSoup.parse(input).select("a")
        let commentIds = commentElements
            .array()
            .filter { ((try? $0.text()) ?? "").contains("favorite") }
            .map { try? $0.attr("href") }
            .compactMap { $0 }
            .filter { $0.hasPrefix("fave?id=") }
            .map(self.extractStoryID)
            .compactMap { $0 }
            .uniqued()
        
        guard storyIds.count == commentIds.count else {
            return []
        }
        
        return Array(zip(storyIds, commentIds))
    }

    private func loadVotedIDPairs(request: URLRequest) async throws -> [(Int, Int)] {
        let data = try await loader.execute(request: request)
        
        guard let input = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Extract all the on story elements
        let onstoryElements: Elements? = try? SwiftSoup.parse(input).getElementsByClass("onstory")
        
        guard let storyElements = onstoryElements else {
            return []
        }
        
        let storyIds: [Int] = storyElements.array()
            .map { try? $0.select("a[href]").array().first?.attr("href") }
            .compactMap { $0 }
            .filter { $0.hasPrefix("item?id=") }
            .map(extractCommentParentStoryID)
            .compactMap { $0 }
        
        // Extract all the links elements
        let commentElements: Elements = try! SwiftSoup.parse(input).getElementsByClass("age")
        let commentIds: [Int] = commentElements
            .array()
            .map { try? $0.select("a[href]").array().first?.attr("href") }
            .compactMap { $0 }
            .filter { $0.hasPrefix("item?id=") }
            .map(extractCommentParentStoryID)
            .compactMap { $0 }
            .uniqued()
        
        guard storyIds.count == commentIds.count else {
            return []
        }
        
        return Array(zip(storyIds, commentIds))
    }
    
    private func extractCommentParentStoryID(input: String) -> Int? {
        let start = "item?id="

        guard let startIndex = input.indices(of: start).first else {
            return nil
        }
        let mod = input.index(startIndex, offsetBy: start.count)
        let output = String(input[mod..<input.endIndex])

        return (Int(output) ?? 0)
    }
}

// MARK: - RateLimitedNetworkResourceLoader

enum NetworkResourceLoaderError: Error {
    case notHTTPURLResponse
    case noData
    case unsuccessfull(Int)
}

protocol URLRequestLoader {
    func load(url: URL) async throws -> Data
    func execute(request: URLRequest) async throws -> Data
    func execute(request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void)
}

/// Requests to `https://news.ycombinator.com` need to be rate limited,
/// otherwise HN will complain that request are comming in too.
class RateLimitedNetworkResourceLoader: URLRequestLoader {
    let session: URLSession!
    var tasks = Queue<URLSessionDataTask>()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true

        self.session = URLSession(configuration: configuration)

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
            if let task = self.tasks.dequeue() {
                task.resume()
            }
        }
    }
    
    func load(url: URL) async throws -> Data {
        return try await execute(request: URLRequest(url: url))
    }
    
    func execute(request: URLRequest) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            execute(request: request, completion: { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let failure):
                    continuation.resume(throwing: failure)
                }
            })
        }
    }

    func execute(request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        let request = request
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse else {
                return completion(Result.failure(NetworkResourceLoaderError.notHTTPURLResponse))
            }

            switch response.statusCode {
            case 200 ... 299:
                guard let data = data else {
                    return completion(Result.success(Data()))
                }
                completion(Result.success(data))
            default:
                guard let error = error else {
                    return completion(Result.failure(NetworkResourceLoaderError.unsuccessfull(response.statusCode)))
                }
                completion(Result.failure(error))
            }
        }
        tasks.enqueue(element: task)
    }
}

struct Queue<T: Equatable> {
    public var items:[T] = []
    
    public init() {}

    public mutating func enqueue(element: T) {
        items.append(element)
    }

    public mutating func dequeue() -> T? {
        if items.isEmpty {
            return nil
        } else {
            let tempElement = items.first
            items.remove(at: 0)
            return tempElement
        }
    }

    public func contains(item: T) -> Bool {
        return items.contains(where: {
            $0 == item
        })
    }
}
