import Foundation

/// Defines endpoints, client credentials, redirect targets, and URL builders for Vercel OAuth 2.0.
public struct OAuthConfig: Sendable, Equatable {
    public let clientId: String
    public let clientSecret: String?
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let redirectURI: String
    public let callbackScheme: String
    public let defaultScopes: [String]
    
    public static let defaultClientId = "oac_VercelPulseDefault"
    public static let defaultRedirectURI = "vercelpulse://oauth-callback"
    public static let defaultCallbackScheme = "vercelpulse"
    public static let defaultAuthEndpoint = URL(string: "https://vercel.com/oauth/authorize")!
    public static let defaultTokenEndpoint = URL(string: "https://api.vercel.com/v2/oauth/access_token")!
    
    public static var configuredClientId: String {
        if let custom = UserDefaults.standard.string(forKey: "oauth_client_id"), !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return defaultClientId
    }
    
    public static var configuredClientSecret: String? {
        if let custom = UserDefaults.standard.string(forKey: "oauth_client_secret"), !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    public static let `default` = OAuthConfig()
    
    public static var current: OAuthConfig {
        OAuthConfig(
            clientId: configuredClientId,
            clientSecret: configuredClientSecret,
            authorizationEndpoint: defaultAuthEndpoint,
            tokenEndpoint: defaultTokenEndpoint,
            redirectURI: defaultRedirectURI,
            callbackScheme: defaultCallbackScheme,
            defaultScopes: []
        )
    }
    
    public init(
        clientId: String? = nil,
        clientSecret: String? = nil,
        authorizationEndpoint: URL = OAuthConfig.defaultAuthEndpoint,
        tokenEndpoint: URL = OAuthConfig.defaultTokenEndpoint,
        redirectURI: String = OAuthConfig.defaultRedirectURI,
        callbackScheme: String = OAuthConfig.defaultCallbackScheme,
        defaultScopes: [String] = []
    ) {
        self.clientId = clientId ?? OAuthConfig.configuredClientId
        self.clientSecret = clientSecret ?? OAuthConfig.configuredClientSecret
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.redirectURI = redirectURI
        self.callbackScheme = callbackScheme
        self.defaultScopes = defaultScopes
    }
    
    /// Constructs the full OAuth 2.0 authorization URL with anti-CSRF state, PKCE challenge, and scopes.
    public func buildAuthorizationURL(
        state: String,
        pkce: PKCEPair?,
        scopes: [String]? = nil
    ) throws -> URL {
        guard var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false) else {
            throw OAuthError.invalidConfiguration("Invalid authorization endpoint URL: \(authorizationEndpoint)")
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "response_type", value: "code")
        ]
        
        if let pkce = pkce {
            queryItems.append(URLQueryItem(name: "code_challenge", value: pkce.codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod))
        }
        
        let targetScopes = scopes ?? defaultScopes
        if !targetScopes.isEmpty {
            queryItems.append(URLQueryItem(name: "scope", value: targetScopes.joined(separator: " ")))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw OAuthError.invalidConfiguration("Failed to construct authorization URL from components")
        }
        
        return url
    }
    
    /// Convenience URL builder overload accepting an optional code challenge string.
    public func authorizationURL(
        state: String,
        codeChallenge: String? = nil,
        scopes: [String]? = nil
    ) throws -> URL {
        let pkce: PKCEPair? = codeChallenge.map { PKCEPair(codeVerifier: "", codeChallenge: $0, codeChallengeMethod: "S256") }
        return try buildAuthorizationURL(state: state, pkce: pkce, scopes: scopes)
    }
    
    /// Static helper for generating code verifiers.
    public static func generateCodeVerifier(length: Int = 64) -> String {
        return PKCEHelper.generateCodeVerifier(length: length)
    }
    
    /// Static helper for computing code challenges.
    public static func generateCodeChallenge(for verifier: String) -> String {
        return PKCEHelper.computeChallenge(for: verifier)
    }
}
