import Foundation

public struct TestOAuthToken: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String
    public let expiresIn: Int?
    public let expiresAt: Date?
    public let scope: String?
    public let teamId: String?
    public let userId: String?
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: Int? = 86400,
        expiresAt: Date? = nil,
        scope: String? = nil,
        teamId: String? = nil,
        userId: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt ?? (expiresIn != nil ? Date().addingTimeInterval(TimeInterval(expiresIn!)) : nil)
        self.scope = scope
        self.teamId = teamId
        self.userId = userId
    }
    
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    public var shouldRefresh: Bool {
        guard let expiresAt = expiresAt else { return false }
        // Proactive threshold: refresh if <= 60s remaining
        return expiresAt.timeIntervalSinceNow <= 60
    }
}

public protocol TestKeychainManaging: Sendable {
    func save(key: String, string: String) throws
    func save(key: String, data: Data) throws
    func getString(key: String) -> String?
    func getData(key: String) throws -> Data?
    func delete(key: String) throws
    func purgeAll() throws
    func saveToken(_ token: TestOAuthToken) throws
    func getToken() -> TestOAuthToken?
}

public final class MockKeychainManager: @unchecked Sendable, TestKeychainManaging {
    public enum MockKeychainError: Error, LocalizedError, Equatable {
        case itemNotFound
        case duplicateItem
        case writeFailed(String)
        case decodingError
        case simulatedFailure
        
        public var errorDescription: String? {
            switch self {
            case .itemNotFound: return "Item not found in keychain"
            case .duplicateItem: return "Duplicate item in keychain"
            case .writeFailed(let msg): return "Keychain write failed: \(msg)"
            case .decodingError: return "Failed to decode data from keychain"
            case .simulatedFailure: return "Simulated Keychain error"
            }
        }
    }
    
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    
    public var saveCallCount = 0
    public var getCallCount = 0
    public var deleteCallCount = 0
    public var purgeCallCount = 0
    
    public var shouldFailNextSave = false
    public var shouldFailNextGet = false
    public var shouldFailNextDelete = false
    
    public static let tokenKey = "com.vercelpulse.oauth.token"
    public static let legacyTokenKey = "com.vercelpulse.token"
    
    public init() {}
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        saveCallCount = 0
        getCallCount = 0
        deleteCallCount = 0
        purgeCallCount = 0
        shouldFailNextSave = false
        shouldFailNextGet = false
        shouldFailNextDelete = false
    }
    
    public func save(key: String, string: String) throws {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw MockKeychainError.simulatedFailure
        }
        guard let data = string.data(using: .utf8) else {
            throw MockKeychainError.writeFailed("Cannot encode string to UTF-8")
        }
        storage[key] = data
    }
    
    public func save(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw MockKeychainError.simulatedFailure
        }
        storage[key] = data
    }
    
    public func getString(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        getCallCount += 1
        if shouldFailNextGet {
            shouldFailNextGet = false
            return nil
        }
        guard let data = storage[key] else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public func getData(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        getCallCount += 1
        if shouldFailNextGet {
            shouldFailNextGet = false
            throw MockKeychainError.simulatedFailure
        }
        return storage[key]
    }
    
    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        deleteCallCount += 1
        if shouldFailNextDelete {
            shouldFailNextDelete = false
            throw MockKeychainError.simulatedFailure
        }
        storage.removeValue(forKey: key)
    }
    
    public func purgeAll() throws {
        lock.lock()
        defer { lock.unlock() }
        purgeCallCount += 1
        storage.removeAll()
    }
    
    public func saveToken(_ token: TestOAuthToken) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(token)
        try save(key: MockKeychainManager.tokenKey, data: data)
    }
    
    public func getToken() -> TestOAuthToken? {
        if let data = try? getData(key: MockKeychainManager.tokenKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(TestOAuthToken.self, from: data)
        }
        // Check legacy token key fallback
        if let legacyString = getString(key: MockKeychainManager.legacyTokenKey) {
            return TestOAuthToken(accessToken: legacyString)
        }
        return nil
    }
    
    public func allKeys() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}
