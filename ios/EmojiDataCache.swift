import Foundation

struct EmojiDataSnapshot: Sendable {
    let sections: [EmojiSection]
    let keywords: [String: [String]]
}

private actor EmojiDataCacheStorage {
    private var cachedSnapshot: EmojiDataSnapshot?

    func load(loader: @Sendable () -> EmojiDataSnapshot) -> EmojiDataSnapshot {
        if let cachedSnapshot {
            return cachedSnapshot
        }

        let snapshot = loader()
        cachedSnapshot = snapshot
        return snapshot
    }
}

final class EmojiDataCache {
    static let shared = EmojiDataCache()

    private let storage = EmojiDataCacheStorage()
    private let stateLock = NSLock()
    private var hasCachedDataSnapshot = false

    private init() {}

    var hasCachedData: Bool {
        stateLock.withLock { hasCachedDataSnapshot }
    }

    func warm(loader: @escaping @Sendable () -> EmojiDataSnapshot) {
        Task.detached(priority: .utility) {
            _ = await self.load(loader: loader)
        }
    }

    func load(loader: @escaping @Sendable () -> EmojiDataSnapshot) async -> EmojiDataSnapshot {
        let snapshot = await storage.load(loader: loader)
        stateLock.withLock {
            hasCachedDataSnapshot = true
        }
        return snapshot
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
