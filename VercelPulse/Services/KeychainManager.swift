import Foundation
import Security

/// Keys used to store authentication items in the Keychain.
public enum KeychainKeys {
    /// Key for the full serialized OAuthToken payload.
    public static let oauthToken = "com.vercelpulse.oauth_token"
    /// Legacy key for raw Personal Access Token (PAT) string.
    public static let legacyToken = "com.vercelpulse.token"
    /// Optional stored team ID override.
    public static let teamId = "com.vercelpulse.team_id"
    /// Optional stored user ID.
    public static let userId = "com.vercelpulse.user_id"
}

/// Errors thrown by Keychain operations.
public enum KeychainError: Error, LocalizedError, Equatable, Sendable {
    case itemNotFound
    case duplicateItem
    case invalidData
    case encodingError(String)
    case decodingError(String)
    case unhandledError(status: OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .duplicateItem:
            return "The item already exists in the Keychain."
        case .invalidData:
            return "The data could not be converted to or from the required format."
        case .encodingError(let details):
            return "Failed to encode token: \(details)"
        case .decodingError(let details):
            return "Failed to decode token: \(details)"
        case .unhandledError(let status):
            if let message = SecCopyErrorMessageString(status, nil) {
                return "Keychain error (\(status)): \(message as String)"
            }
            return "Keychain operation failed with OSStatus: \(status)"
        }
    }
}

/// Contract for Keychain persistence operations.
public protocol KeychainManaging: Sendable {
    func save(key: String, string: String) throws
    func save(key: String, data: Data) throws
    func getString(key: String) -> String?
    func getData(key: String) throws -> Data?
    func delete(key: String) throws
    func purgeAll() throws
    func saveToken(_ token: OAuthToken) throws
    func getToken() -> OAuthToken?
}

/// Thread-safe manager for macOS Keychain persistence conforming to `KeychainManaging`.
public final class KeychainManager: KeychainManaging, @unchecked Sendable {
    
    // MARK: - Singleton & Configuration
    
    public static let shared = KeychainManager()
    
    public let serviceName: String
    public let accessGroup: String?
    
    private let lock = NSLock()
    
    // MARK: - Initializer
    
    public init(serviceName: String = "com.vercelpulse.token", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    // MARK: - Core Multi-Key CRUD
    
    /// Saves raw Data to the Keychain under the specified key.
    /// If an item with this key already exists, updates it seamlessly.
    public func save(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Automatic fallback to SecItemUpdate
            var matchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key
            ]
            if let accessGroup = accessGroup {
                matchQuery[kSecAttrAccessGroup as String] = accessGroup
            }
            
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            
            let updateStatus = SecItemUpdate(matchQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Saves a UTF-8 string to the Keychain under the specified key.
    public func save(key: String, string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(key: key, data: data)
    }
    
    /// Retrieves raw Data for the specified key.
    public func getData(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Retrieves a UTF-8 string for the specified key.
    public func getString(key: String) -> String? {
        guard let data = try? getData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Deletes a specific key from the Keychain.
    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Purges all items stored under this service identifier.
    public func purgeAll() throws {
        lock.lock()
        defer { lock.unlock() }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var status = SecItemDelete(query as CFDictionary)
        while status == errSecSuccess {
            status = SecItemDelete(query as CFDictionary)
        }
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - OAuthToken High-Level Operations
    
    /// Persists an `OAuthToken` structure to the Keychain.
    public func saveToken(_ token: OAuthToken) throws {
        do {
            let data = try JSONEncoder().encode(token)
            try save(key: KeychainKeys.oauthToken, data: data)
        } catch let error as KeychainError {
            throw error
        } catch {
            throw KeychainError.encodingError(error.localizedDescription)
        }
    }
    
    /// Retrieves the current `OAuthToken` from Keychain.
    /// Transparently falls back to legacy raw PAT string token if present.
    public func getToken() -> OAuthToken? {
        // 1. Try to read full OAuthToken payload
        if let data = try? getData(key: KeychainKeys.oauthToken) {
            if let token = try? JSONDecoder().decode(OAuthToken.self, from: data) {
                return token
            }
        }
        
        // 2. Backwards compatibility fallback: Check legacy raw string token
        if let legacyString = getString(key: KeychainKeys.legacyToken), !legacyString.isEmpty {
            return OAuthToken(
                accessToken: legacyString,
                refreshToken: nil,
                tokenType: "Bearer",
                expiresIn: nil,
                expiresAt: nil,
                scope: nil,
                teamId: nil,
                userId: nil
            )
        }
        
        return nil
    }
    
    // MARK: - Backwards Compatibility API Overloads
    
    /// Legacy method: Saves a raw Personal Access Token (PAT) string.
    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? delete(key: KeychainKeys.legacyToken)
            try? delete(key: KeychainKeys.oauthToken)
            return true
        }
        
        let oauthToken = OAuthToken(
            accessToken: trimmed,
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: nil,
            expiresAt: nil,
            scope: nil,
            teamId: nil,
            userId: nil
        )
        
        do {
            try saveToken(oauthToken)
            // Also store under legacy key for legacy consumers
            try save(key: KeychainKeys.legacyToken, string: trimmed)
            return true
        } catch {
            return false
        }
    }
    
    /// Legacy method: Returns the access token string if available.
    public func getAccessToken() -> String? {
        let token: OAuthToken? = getToken()
        return token?.accessToken
    }
    
    /// Legacy method: Deletes all stored tokens.
    public func deleteToken() {
        try? delete(key: KeychainKeys.oauthToken)
        try? delete(key: KeychainKeys.legacyToken)
    }
}
