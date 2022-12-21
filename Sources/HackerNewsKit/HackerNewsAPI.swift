import Combine
import AsyncAlgorithms
import Firebase

public enum MainFeedType: String {
    case top = "topstories"
    case best = "beststories"
    case new = "newstories"
    case ask = "askstories"
    case show = "showstories"
    case jobs = "jobs"
}

public enum SavedItemsFeedType {
    case savedStories
    case savedComments
    case favoriteStories
    case favoriteComments
}

public enum SaveType: String {
    case favorite = "favorites"
    case upvote = "upvoted"
}

public enum VoteActionType: String {
    case upvote
    case undo
}

public enum FavoriteActionType: String {
    case add
    case remove
}

public struct HackerNewsAPI {
    public static let shared = HackerNewsAPI()
    
    private let firebase = HackerNewsFirebaseAPI()
    private let hnPrivateAPI = HackerNewsPrivateAPI()
    private let searchService = AlgoliaAPI()
    
    /// Needs to be calles right after the app stars to configure Firebase.
    public static func configureFirebase() {
        FirebaseApp.configure()
    }
    
    public init() {}
    
    /// Checks the cookie storage for a stored cookie.
    public var isLoggedIn: Bool {
        UserStorage.isLoggedIn
    }
    
    /// Checks the cookie storage for a stored cookie and if present returns the latest saved username.
    public var loggedInUser: String? {
        return UserStorage.loggedInUser
    }
    
    /// Sign in with the provided username and password.
    ///
    /// It makes a login request to `https://news.ycombinator.com/login` since the official hacker news API does not provide a sign in method.
    /// If the login is successful it stores the cookie in the cookie storage
    public func singIn(username: String, password: String) async throws {
         try await hnPrivateAPI.login(username: username, password: password)
    }
    
    /// Returns all main feed items based on the requested type.
    ///
    /// Loading all the items at once can take a bit more time,
    /// optionally you can provide the start index and the items count in the requested feed.
    public func mainFeedItems(feedType: MainFeedType, startIndex: Int = 0, count: Int = 500) async throws -> [StoryItem] {
        let allIDs = feedType == .jobs ?
        try await hnPrivateAPI.jobIDs() :
        try await firebase.storiesIDs(for: feedType).ids
        
        return try await firebase
            .items(for: allIDs)
            .compactMap { StoryItem(rawItem: $0) }
    }
    
    /// Searches stories with the provided query using Algolia HN Search API `https://hn.algolia.com/api`.
    public func search(query: String) async throws -> [StoryItem] {
        let ids = try await searchService.searchIDs(query: query)
        return try await firebase.items(for: ids).compactMap { StoryItem(rawItem: $0) }
    }
    
    /// Create a custom commet async sequence,
    public func comments(with roots: [Int]) -> CommentAsyncSequence {
        return CommentAsyncSequence(items: roots)
    }
    
    /// Returns an async channel that 
    public func savedStories(of type: SaveType) throws -> AsyncChannel<[StoryItem]> {
        let channel = AsyncChannel<[StoryItem]>()
        
        Task {
            let idChunks = try hnPrivateAPI.savedStoriesIDs(type: type)
            let storyChunks = idChunks.map { try await firebase.items(for: $0) }
            
            for try await items in storyChunks {
                let stories = items.compactMap { StoryItem(rawItem: $0) }
                await channel.send(stories)
            }
        }
        
        return channel
    }
    
    public func savedComments(of type: SaveType) throws -> AsyncChannel<[(parentStory: StoryItem, comment: CommentItem)]> {
        let channel = AsyncChannel<[(parentStory: StoryItem, comment: CommentItem)]>()

        Task {
            let zippedChunks = try hnPrivateAPI.savedCommentsIDs(type: type).map { tuples in
                let stories = try await firebase
                    .items(for: tuples.map { $0.parentStoryID })
                    .compactMap { StoryItem(rawItem: $0) }
                
                let comments = try await firebase
                    .items(for: tuples.map { $0.commentID })
                    .compactMap { CommentItem(rawItem: $0) }

                let savedComments: [(parentStory: StoryItem, comment: CommentItem)] = Array(zip(stories, comments))
                
                return savedComments
            }

            for try await chunks in zippedChunks {
                try Task.checkCancellation()
                await channel.send(chunks)
            }
        }

        return channel
    }
    
    public func vote(id: Int, actionType: VoteActionType) async throws {
        switch actionType {
        case .upvote:
            try await hnPrivateAPI.upvote(id: id)
        case .undo:
            try await hnPrivateAPI.unvote(id: id)
        }
    }
    
    public func favorite(id: Int, actionType: FavoriteActionType) async throws {
        switch actionType {
        case .add:
            try await hnPrivateAPI.favorite(id: id)
        case .remove:
            try await hnPrivateAPI.unfavorite(id: id)
        }
    }
    
    public func postCommentReply(id: Int, text: String) async throws {
        try await hnPrivateAPI.postCommentReply(to: id, with: text)
    }
    
    public func postStoryReply(id: Int, text: String) async throws {
        try await hnPrivateAPI.postStoryReply(to: id, goto: id, with: text)
    }
}
