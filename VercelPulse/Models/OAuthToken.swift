import Foundation

/// Represents a Vercel OAuth 2.0 token payload with lifecycle metadata.
public struct OAuthToken: Codable, Equatable, Sendable {
    
    // MARK: - Properties
    
    /// The Bearer access token used to authenticate API requests.
    public let accessToken: String
    
    /// The refresh token used to obtain a new access token when expired.
    public let refreshToken: String?
    
    /// The token type (typically "Bearer").
    public let tokenType: String
    
    /// Lifespan of the access token in seconds from issuance.
    public let expiresIn: Int?
    
    /// Absolute timestamp when the access token expires.
    public let expiresAt: Date?
    
    /// Granted OAuth scopes.
    public let scope: String?
    
    /// Associated Vercel Team ID if authorized for a specific team.
    public let teamId: String?
    
    /// Associated Vercel User ID.
    public let userId: String?
    
    // MARK: - Initializer
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: Int? = nil,
        expiresAt: Date? = nil,
        scope: String? = nil,
        teamId: String? = nil,
        userId: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        if let expiresAt = expiresAt {
            self.expiresAt = expiresAt
        } else if let expiresIn = expiresIn {
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            self.expiresAt = nil
        }
        self.scope = scope
        self.teamId = teamId
        self.userId = userId
    }
    
    // MARK: - Lifecycle Helpers
    
    /// Returns `true` if the token has expired past its `expiresAt` timestamp.
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    /// Checks if the token is expired or will expire within the given threshold (default: 60 seconds).
    /// Used for proactive token refresh before making critical API requests.
    public func isExpiring(within seconds: TimeInterval = 60) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date().addingTimeInterval(seconds) >= expiresAt
    }
    
    /// Checks if the token should be proactively refreshed (default: 60 seconds threshold).
    public func isExpiringSoon(threshold: TimeInterval = 60) -> Bool {
        return isExpiring(within: threshold)
    }
    
    /// Proactive refresh flag (expires in <= 60 seconds).
    public var shouldRefresh: Bool {
        return isExpiring(within: 60)
    }
    
    /// Validates that the access token is non-empty and has not expired.
    public var isValid: Bool {
        return !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isExpired
    }
    
    /// Returns true if the access token string is empty.
    public var isEmpty: Bool {
        return accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Approximate remaining lifetime in seconds, or nil if token has no expiration.
    public var timeRemaining: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    // MARK: - Codable Custom Mapping
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accessTokenCamel = "accessToken"
        case refreshToken = "refresh_token"
        case refreshTokenCamel = "refreshToken"
        case tokenType = "token_type"
        case tokenTypeCamel = "tokenType"
        case expiresIn = "expires_in"
        case expiresInCamel = "expiresIn"
        case expiresAt = "expires_at"
        case expiresAtCamel = "expiresAt"
        case scope
        case teamId = "team_id"
        case teamIdCamel = "teamId"
        case userId = "user_id"
        case userIdCamel = "userId"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Access Token: check snake_case then camelCase
        if let token = try container.decodeIfPresent(String.self, forKey: .accessToken) {
            self.accessToken = token
        } else if let token = try container.decodeIfPresent(String.self, forKey: .accessTokenCamel) {
            self.accessToken = token
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.accessToken,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing access_token or accessToken")
            )
        }
        
        // Refresh Token
        self.refreshToken = (try? container.decodeIfPresent(String.self, forKey: .refreshToken)) ??
                            (try? container.decodeIfPresent(String.self, forKey: .refreshTokenCamel))
        
        // Token Type (default "Bearer")
        let decodedType = (try? container.decodeIfPresent(String.self, forKey: .tokenType)) ??
                          (try? container.decodeIfPresent(String.self, forKey: .tokenTypeCamel))
        self.tokenType = decodedType ?? "Bearer"
        
        // Expires In
        let decodedExpiresIn = (try? container.decodeIfPresent(Int.self, forKey: .expiresIn)) ??
                               (try? container.decodeIfPresent(Int.self, forKey: .expiresInCamel))
        self.expiresIn = decodedExpiresIn
        
        // Expires At
        var decodedExpiresAt = (try? container.decodeIfPresent(Date.self, forKey: .expiresAt)) ??
                               (try? container.decodeIfPresent(Date.self, forKey: .expiresAtCamel))
        
        // Calculate expiresAt from expiresIn if not explicitly set
        if decodedExpiresAt == nil, let expiresIn = decodedExpiresIn {
            decodedExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        }
        self.expiresAt = decodedExpiresAt
        
        // Scope
        self.scope = try? container.decodeIfPresent(String.self, forKey: .scope)
        
        // Team ID
        self.teamId = (try? container.decodeIfPresent(String.self, forKey: .teamId)) ??
                      (try? container.decodeIfPresent(String.self, forKey: .teamIdCamel))
        
        // User ID
        self.userId = (try? container.decodeIfPresent(String.self, forKey: .userId)) ??
                      (try? container.decodeIfPresent(String.self, forKey: .userIdCamel))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encodeIfPresent(expiresIn, forKey: .expiresIn)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(teamId, forKey: .teamId)
        try container.encodeIfPresent(userId, forKey: .userId)
    }
}

extension OAuthToken: CustomStringConvertible {
    public var description: String {
        return accessToken
    }
}
