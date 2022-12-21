import Foundation

public struct RawItem: Decodable {
    public let id: Int?
    public let deleted: Bool?
    public let dead: Bool?
    public let type: String?
    public let by: String?
    public let title: String?
    public let text: String?
    public let parent: Int?
    public let descendants: Int?
    public let kids: [Int]?
    public let score: Int?
    public let time: Int?
    public let url: String?
    public let parts: [Int]?
    public var index: Int?
}

public extension RawItem {
    init(_ dict: [String: Any]) {
        id = dict["id"] as? Int
        deleted = (dict["deleted"] as? Bool) ?? false
        dead = (dict["dead"] as? Bool) ?? false
        type = dict["type"] as? String
        by = dict["by"] as? String
        title = dict["title"] as? String
        text = dict["text"] as? String
        parent = dict["parent"] as? Int
        descendants = dict["descendants"] as? Int
        kids = dict["kids"] as? [Int]
        score = dict["score"] as? Int
        time = dict["time"] as? Int
        url = dict["url"] as? String
        parts = dict["parts"] as? [Int]
    }
}

public struct RawUser: Decodable {
    public let created: Int?
    public let id: String?
    public let karma: Int?
    public let submitted: [Int]?
}

public struct User: Equatable {
    public let created: Int
    public let id: String
    public let karma: Int
    public let submitted: [Int]
}

public extension RawUser {
    init(_ dict: [String: Any]) {
        created = dict["created"] as? Int
        id = dict["id"] as? String
        karma = dict["karma"] as? Int
        submitted = dict["submitted"] as? [Int]
    }
}

public struct StoryItem: Equatable, Identifiable, Hashable {
    public let id: Int
    public let deleted: Bool
    public let dead: Bool
    public let title: String
    public let text: String?
    public let url: URL?
    public var index: Int?
    public let author: String
    public let time: String
    public let commentsCount: Int
    public let kids: [Int]
    public let score: Int
    
    public init?(rawItem: RawItem) {
        guard let type = rawItem.type, (type == "story" || type == "job")  else { return nil }
        let urlString = rawItem.url ?? ""
        
        self.id = rawItem.id ?? 0
        self.deleted = rawItem.deleted ?? false
        self.dead = rawItem.dead ?? false
        self.title = rawItem.title ?? ""
        self.text = rawItem.text
        self.url = urlString.isEmpty ? nil : URL(string: urlString)
        self.index = rawItem.index
        self.author = rawItem.by ?? ""
        self.time = Date(timeIntervalSince1970: Double(rawItem.time ?? 0)).timeAgoSinceDate()
        self.commentsCount = rawItem.descendants ?? 0
        self.kids = rawItem.kids ?? []
        self.score = rawItem.score ?? 0
    }
}

public extension StoryItem {
    var shortURLString: String {
        guard let url = url else { return "news.ycombinator.com" }

        var output = url.host ?? ""
        if output.contains("www.") {
            if let firstDotIndex = output.firstIndex(of: ".") {
                output = String(output[firstDotIndex...])
            }
        }

        return output
    }

    var shareableURL: URL? {
        guard let url = URL(string: "https://news.ycombinator.com/item?id=\(self.id)") else { return nil }
        return url
    }
}

public class CommentItem: Equatable, Identifiable {
    public static func == (lhs: CommentItem, rhs: CommentItem) -> Bool {
        return lhs.id == rhs.id
    }

    public let id: Int
    public let deleted: Bool
    public let dead: Bool
    public let author: String
    public let time: String
    public let parent: Int
    public let kids: [Int]
    public var kidsComments: [CommentItem]
    public let score: Int
    public let text: String

    public var index: Int = 0
    public var anchestors: [Int] = []
    
    init(id: Int,
         deleted: Bool,
         dead: Bool,
         author: String,
         time: String,
         parent: Int,
         kids: [Int],
         kidsComments: [CommentItem],
         score: Int,
         text: String,
         index: Int = 0) {
        self.id = id
        self.deleted = deleted
        self.dead = dead
        self.author = author
        self.time = time
        self.parent = parent
        self.kids = kids
        self.kidsComments = kidsComments
        self.score = score
        self.text = text
        self.index = index
    }
    
    public init?(rawItem: RawItem) {
        guard let type = rawItem.type, type == "comment" else { return nil }
        self.id = rawItem.id ?? 0
        self.deleted = rawItem.deleted ?? false
        self.dead = rawItem.dead ?? false
        self.author = rawItem.by ?? ""
        self.time = Date(timeIntervalSince1970: Double(rawItem.time ?? 0)).timeAgoSinceDate()
        self.parent = rawItem.parent ?? 0
        self.kids = rawItem.kids ?? []
        self.kidsComments = []
        self.score = rawItem.score ?? 0
        self.text = rawItem.text ?? ""
        self.index = rawItem.index ?? 0
    }
}
