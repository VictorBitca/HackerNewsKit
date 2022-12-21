import Foundation

struct CommentFetcher {
    public static func commentStream(with kids: [Int]) -> AsyncStream<RawItem> {
        return AsyncStream { continuation in
            let firebase = HackerNewsFirebaseAPI()
            @Sendable func rawItems(for ids: [Int], level: Int = 0) async {
                guard let parents = try? await firebase.items(for: ids) else { return }
                
                for parent in parents {
                    var parentClone = parent
                    parentClone.index = level
                    continuation.yield(parentClone)
                    if let kids = parent.kids {
                        await rawItems(for: kids, level: level + 1)
                    }
                }
            }
            
            let task = Task {
                await rawItems(for: kids)
                continuation.finish()
            }
            
            continuation.onTermination = { termination in
              switch termination {
              case .finished:
                  break
              case .cancelled:
                  task.cancel()
                  continuation.finish()
              @unknown default:
                  fatalError()
              }
            }
        }
    }
}

public struct CommentAsyncSequence: AsyncSequence {
    public typealias Element = RawItem

    public let items: [Int]
    public let level: Int
    
    public init(items: [Int], level: Int = 0) {
        self.items = items
        self.level = level
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let firebase = HackerNewsFirebaseAPI()
        let items: [Int]
        let level: Int
        
        var fetchedRawItems: [RawItem] = []
        var rawItemsFetched: Bool = false
        
        var currentItemIndex: Int = 0
        var currentItemIndexReturned: Bool = false
        
        var currentItemChildenSequenceIterator: (any AsyncIteratorProtocol)? = nil
        
        mutating func fetchRawItemsOnce() async {
            rawItemsFetched = true
            guard let rawItems = try? await firebase.items(for: items) else { return }
            
            fetchedRawItems = rawItems.map {
                var clone = $0
                clone.index = level
                return clone
            }
        }
        
        public mutating func next() async -> RawItem? {
            try? Task.checkCancellation()
            
            if items.isEmpty { return nil }
            
            if !rawItemsFetched { await fetchRawItemsOnce() }
            
            if fetchedRawItems.isEmpty { return nil }
            
            if !currentItemIndexReturned {
                currentItemIndexReturned = true
                guard let currentItem = fetchedRawItems[safe: currentItemIndex] else { return nil }
                currentItemChildenSequenceIterator = CommentAsyncSequence(items: currentItem.kids ?? [], level: level + 1).makeAsyncIterator()
            
                return currentItem
            }
            
            guard let childItem = await (try? currentItemChildenSequenceIterator?.next()) as? RawItem else {
                currentItemIndex += 1
                guard let currentItem = fetchedRawItems[safe: currentItemIndex] else { return nil }
                currentItemChildenSequenceIterator = CommentAsyncSequence(items: currentItem.kids ?? [], level: level + 1).makeAsyncIterator()
                
                return currentItem
            }
            
            return childItem
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(items: items, level: level)
    }
}
