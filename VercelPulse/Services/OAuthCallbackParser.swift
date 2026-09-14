import Foundation

/// Parsed OAuth authorization response payload.
public struct OAuthCallbackResult: Equatable, Sendable {
    public let code: String
    public let state: String
    public let teamId: String?
    public let configurationId: String?
    
    public init(
        code: String,
        state: String,
        teamId: String? = nil,
        configurationId: String? = nil
    ) {
        self.code = code
        self.state = state
        self.teamId = teamId
        self.configurationId = configurationId
    }
}

/// Helper for parsing and verifying OAuth callback URLs.
public enum OAuthCallbackParser {
    
    /// Parses a redirect URL and verifies anti-CSRF state and authorization code.
    public static func parse(url: URL, expectedState: String? = nil) throws -> OAuthCallbackResult {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw OAuthError.invalidCallbackURL(url.absoluteString)
        }
        
        // Verify scheme
        guard let scheme = components.scheme?.lowercased(), scheme == "vercelpulse" else {
            throw OAuthError.invalidCallbackURL("Expected scheme vercelpulse://, received \(components.scheme ?? "")")
        }
        
        let queryItems = components.queryItems ?? []
        let params = Dictionary(queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        }, uniquingKeysWith: { first, _ in first })
        
        // 1. Check for server error or denial
        if let error = params["error"] {
            let errorDesc = params["error_description"]
            if error == "access_denied" {
                throw OAuthError.userCancelled
            }
            throw OAuthError.serverError(error: error, description: errorDesc)
        }
        
        // 2. Validate anti-CSRF state
        if let expectedState = expectedState {
            guard let state = params["state"], !state.isEmpty else {
                throw OAuthError.stateMismatch(expected: expectedState, received: "<missing>")
            }
            guard state == expectedState else {
                throw OAuthError.stateMismatch(expected: expectedState, received: state)
            }
        }
        
        // 3. Extract code
        guard let code = params["code"], !code.isEmpty else {
            throw OAuthError.missingAuthorizationCode
        }
        
        return OAuthCallbackResult(
            code: code,
            state: params["state"] ?? "",
            teamId: params["teamId"],
            configurationId: params["configurationId"]
        )
    }
}
