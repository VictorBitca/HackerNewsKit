import Foundation
import Firebase
import Combine
import UIKit

public protocol IDsProviding {
    var ids: [Int] { get }
}

extension Array: IDsProviding where Element == Int {
    public var ids: [Int] { return self }
}

/// Firebase Wrapper for the official hacker news API `https://github.com/HackerNews/API`
extension HackerNewsFirebaseAPI {
    func storiesIDs(for type: MainFeedType) async throws -> IDsProviding {
        return await withCheckedContinuation { continuation in
            self.loadStoriesIDs(path: type.rawValue) { IDs in
                continuation.resume(returning: IDs)
            }
        }
    }
    
    func items(for ids: [Int]) async throws -> [RawItem] {
        guard !ids.isEmpty else { return [] }
        
        return await withCheckedContinuation { continuation in
            self.loadRawItems(ids: ids) { rawItems in
                continuation.resume(returning: rawItems)
            }
        }
    }
}

struct HackerNewsFirebaseAPI {
    private let database = Database.database().reference()

    private func loadStoriesIDs(path: String, completion: @escaping ([Int]) -> ()) {
        let stories = database.child("v0").child(path)

        stories.queryLimited(toFirst: 500).observeSingleEvent(of: .value) { snapshot in
            if let ids = snapshot.value as? [Int] {
                completion(ids)
            }
        }
    }

    func loadRawUser(name: String, completion: @escaping (RawUser?) -> Void) {
        let itemQuerry = database.child("v0").child("user")
        itemQuerry.child(name).observeSingleEvent(of: .value) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else { return completion(nil) }
            completion(RawUser(dict))
        }
    }

    func loadRawItems(ids: [Int], completion: @escaping ([RawItem]) -> Void) {
        let requestedItemsCount = ids.count
        let itemQuerry = database.child("v0").child("item")
        var loadedItemsCount = 0
        var loadedItemsKeyValMap = [Int: RawItem]()

        func returnLoadedItems() {
            let loadedItems = ids
                .compactMap { loadedItemsKeyValMap[$0] }
                .filter { $0.dead == false || $0.deleted == false }
            
            completion(loadedItems)
        }

        func observe(_ id: Int) {
            itemQuerry.child("\(id)").observeSingleEvent(of: .value, with: { snapshot in
                loadedItemsCount += 1
                
                if let dict = snapshot.value as? [String: Any] {
                    let rawItem = RawItem(dict)
                    loadedItemsKeyValMap[rawItem.id ?? 0] = rawItem
                    if loadedItemsCount == requestedItemsCount { returnLoadedItems() }
                }
            }) { (error) in
                loadedItemsCount += 1
            }
        }

        ids.forEach { id in observe(id) }
    }
}
