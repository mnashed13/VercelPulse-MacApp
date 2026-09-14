import Foundation
import AuthenticationServices

/// Public protocol defining the complete Vercel OAuth 2.0 authentication engine contract.
public protocol VercelOAuthServicing: AnyObject, Sendable {
    /// Indicates whether a valid non-empty access token is currently stored.
    var isAuthenticated: Bool { get }
    
    /// Retrieves the current stored OAuthToken, if any.
    var currentToken: OAuthToken? { get }
    
    /// Launches ASWebAuthenticationSession, completes browser login, exchanges code, and saves token.
    func startOAuthFlow() async throws -> OAuthToken
    
    /// Parses custom scheme callback URL, validates anti-CSRF state, and executes token exchange.
    func handleCallback(url: URL) async throws -> OAuthToken
    
    /// Directly exchanges an authorization code and PKCE code_verifier for an OAuthToken.
    func exchangeCode(code: String, codeVerifier: String?, redirectURI: String?, fallbackTeamId: String?) async throws -> OAuthToken
    
    /// Refreshes the active access token using the stored refresh token.
    func refreshToken() async throws -> OAuthToken
    
    /// Returns a valid access token, proactively refreshing it if it expires in less than 60 seconds.
    func getValidAccessToken() async throws -> String
    
    /// Saves a manual Personal Access Token (PAT) for fallback authentication.
    func savePersonalAccessToken(_ pat: String, teamId: String?) throws
    
    /// Purges all tokens from Keychain and resets all cached session state.
    func logout() throws
}

/// Central OAuth 2.0 and PAT authentication engine for VercelPulse.
public final class VercelOAuthService: VercelOAuthServicing, @unchecked Sendable {
    public static let shared = VercelOAuthService()
    
    // Dependencies
    private let keychainManager: KeychainManaging
    private let session: URLSession
    private let config: OAuthConfig
    private let presentationProvider: ASWebAuthenticationPresentationContextProviding
    
    // Thread safety & transient flow state
    private let lock = NSLock()
    private var pendingState: String?
    private var pendingCodeVerifier: String?
    private var refreshTask: Task<OAuthToken, Error>?
    
    public init(
        keychainManager: KeychainManaging = KeychainManager.shared,
        session: URLSession = .shared,
        config: OAuthConfig = .default,
        presentationProvider: ASWebAuthenticationPresentationContextProviding = AuthPresentationContextProvider.shared
    ) {
        self.keychainManager = keychainManager
        self.session = session
        self.config = config
        self.presentationProvider = presentationProvider
    }
    
    // MARK: - Authentication Status
    
    public var isAuthenticated: Bool {
        guard let token = currentToken else { return false }
        return !token.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var currentToken: OAuthToken? {
        return keychainManager.getToken()
    }
    
    // MARK: - OAuth Flow Initiation
    
    public func startOAuthFlow() async throws -> OAuthToken {
        // 1. Generate anti-CSRF state and PKCE challenge
        let state = UUID().uuidString
        let pkcePair: PKCEPair
        do {
            pkcePair = try PKCEHelper.generate()
        } catch {
            let verifier = PKCEHelper.generateCodeVerifier()
            let challenge = PKCEHelper.computeChallenge(for: verifier)
            pkcePair = PKCEPair(codeVerifier: verifier, codeChallenge: challenge, codeChallengeMethod: "S256")
        }
        
        lock.lock()
        pendingState = state
        pendingCodeVerifier = pkcePair.codeVerifier
        lock.unlock()
        
        // 2. Build authorization URL
        let authURL = try config.buildAuthorizationURL(state: state, pkce: pkcePair)
        
        // 3. Launch ASWebAuthenticationSession
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: self.config.callbackScheme
                ) { callbackURL, error in
                    if let error = error {
                        if let asError = error as? ASWebAuthenticationSessionError,
                           asError.code == .canceledLogin {
                            continuation.resume(throwing: OAuthError.userCancelled)
                        } else {
                            continuation.resume(throwing: OAuthError.sessionFailedToStart)
                        }
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: OAuthError.missingCallbackURL)
                        return
                    }
                    
                    continuation.resume(returning: callbackURL)
                }
                
                authSession.presentationContextProvider = self.presentationProvider
                authSession.prefersEphemeralWebBrowserSession = false
                
                guard authSession.start() else {
                    continuation.resume(throwing: OAuthError.sessionFailedToStart)
                    return
                }
            }
        }
        
        // 4. Process callback and exchange token
        return try await handleCallback(url: callbackURL)
    }
    
    // MARK: - Callback Handling
    
    public func handleCallback(url: URL) async throws -> OAuthToken {
        lock.lock()
        let expectedState = pendingState
        let verifier = pendingCodeVerifier
        lock.unlock()
        
        // Parse and validate anti-CSRF state
        let callbackResult = try OAuthCallbackParser.parse(url: url, expectedState: expectedState)
        
        lock.lock()
        pendingState = nil
        pendingCodeVerifier = nil
        lock.unlock()
        
        return try await exchangeCode(
            code: callbackResult.code,
            codeVerifier: verifier,
            redirectURI: config.redirectURI,
            fallbackTeamId: callbackResult.teamId
        )
    }
    
    // MARK: - Token Exchange (POST /v2/oauth/access_token)
    
    public func exchangeCode(
        code: String,
        codeVerifier: String?,
        redirectURI: String? = nil,
        fallbackTeamId: String? = nil
    ) async throws -> OAuthToken {
        let tokenURL = config.tokenEndpoint
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var bodyParams: [String: String] = [
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": redirectURI ?? config.redirectURI
        ]
        
        if let clientSecret = config.clientSecret, !clientSecret.isEmpty {
            bodyParams["client_secret"] = clientSecret
        }
        
        if let verifier = codeVerifier, !verifier.isEmpty {
            bodyParams["code_verifier"] = verifier
        }
        
        request.httpBody = encodeBody(parameters: bodyParams)
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OAuthError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenExchangeFailed(statusCode: 0, message: "Non-HTTP response received.")
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorMsg = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw OAuthError.tokenExchangeFailed(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        let tokenResponse: OAuthTokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        } catch {
            throw OAuthError.decodingError("Failed to decode token response: \(error.localizedDescription)")
        }
        
        let expiresAt: Date? = tokenResponse.expiresIn.map { Date().addingTimeInterval(Double($0)) }
        let token = OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            tokenType: tokenResponse.tokenType,
            expiresIn: tokenResponse.expiresIn,
            expiresAt: expiresAt,
            scope: tokenResponse.scope,
            teamId: tokenResponse.teamId ?? fallbackTeamId,
            userId: tokenResponse.userId
        )
        
        do {
            try keychainManager.saveToken(token)
            if let teamId = token.teamId, !teamId.isEmpty {
                UserDefaults.standard.set(teamId, forKey: "teamId")
            }
        } catch {
            throw OAuthError.keychainError("Failed to persist token: \(error.localizedDescription)")
        }
        
        return token
    }
    
    // MARK: - Token Refresh Flow (grant_type=refresh_token)
    
    public func refreshToken() async throws -> OAuthToken {
        guard let existingToken = keychainManager.getToken() else {
            throw OAuthError.missingToken
        }
        
        guard let refreshToken = existingToken.refreshToken, !refreshToken.isEmpty else {
            throw OAuthError.missingRefreshToken
        }
        
        // Concurrency Deduplication: Join active refresh task if already running
        lock.lock()
        if let activeTask = refreshTask {
            lock.unlock()
            return try await activeTask.value
        }
        
        let task = Task<OAuthToken, Error> {
            defer {
                self.lock.lock()
                self.refreshTask = nil
                self.lock.unlock()
            }
            return try await self.executeTokenRefresh(existingToken: existingToken, refreshToken: refreshToken)
        }
        
        refreshTask = task
        lock.unlock()
        
        return try await task.value
    }
    
    private func executeTokenRefresh(existingToken: OAuthToken, refreshToken: String) async throws -> OAuthToken {
        let tokenURL = config.tokenEndpoint
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var bodyParams: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": config.clientId,
            "refresh_token": refreshToken,
            "redirect_uri": config.redirectURI
        ]
        
        if let clientSecret = config.clientSecret, !clientSecret.isEmpty {
            bodyParams["client_secret"] = clientSecret
        }
        
        request.httpBody = encodeBody(parameters: bodyParams)
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OAuthError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenRefreshFailed(statusCode: 0, message: "Non-HTTP response received.")
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorMsg = parseErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw OAuthError.tokenRefreshFailed(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        let tokenResponse: OAuthTokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        } catch {
            throw OAuthError.decodingError("Failed to decode refresh token response: \(error.localizedDescription)")
        }
        
        let expiresAt: Date? = tokenResponse.expiresIn.map { Date().addingTimeInterval(Double($0)) }
        
        // Retain previous metadata if omitted in refresh response
        let updatedToken = OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? existingToken.refreshToken,
            tokenType: tokenResponse.tokenType.isEmpty ? existingToken.tokenType : tokenResponse.tokenType,
            expiresIn: tokenResponse.expiresIn ?? existingToken.expiresIn,
            expiresAt: expiresAt,
            scope: tokenResponse.scope ?? existingToken.scope,
            teamId: tokenResponse.teamId ?? existingToken.teamId,
            userId: tokenResponse.userId ?? existingToken.userId
        )
        
        do {
            try keychainManager.saveToken(updatedToken)
        } catch {
            throw OAuthError.keychainError("Failed to persist refreshed token: \(error.localizedDescription)")
        }
        
        return updatedToken
    }
    
    // MARK: - Proactive Expiration Check & Token Retrieval
    
    public func getValidAccessToken() async throws -> String {
        guard let token = keychainManager.getToken(), !token.accessToken.isEmpty else {
            throw OAuthError.missingToken
        }
        
        // If token possesses a refresh token and expires within 60 seconds (or is expired), renew proactively
        if token.refreshToken != nil && token.isExpiring(within: 60) {
            let refreshed = try await refreshToken()
            return refreshed.accessToken
        }
        
        return token.accessToken
    }
    
    // MARK: - Manual Personal Access Token (PAT) Fallback
    
    public func savePersonalAccessToken(_ pat: String, teamId: String? = nil) throws {
        let trimmed = pat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OAuthError.missingToken
        }
        
        let token = OAuthToken(
            accessToken: trimmed,
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: nil,
            expiresAt: nil,
            scope: nil,
            teamId: teamId?.trimmingCharacters(in: .whitespacesAndNewlines),
            userId: nil
        )
        
        try keychainManager.saveToken(token)
        if let teamId = token.teamId, !teamId.isEmpty {
            UserDefaults.standard.set(teamId, forKey: "teamId")
        }
    }
    
    // MARK: - Clean Logout & Session Purge
    
    public func logout() throws {
        lock.lock()
        pendingState = nil
        pendingCodeVerifier = nil
        refreshTask?.cancel()
        refreshTask = nil
        lock.unlock()
        
        try keychainManager.purgeAll()
        UserDefaults.standard.removeObject(forKey: "teamId")
    }
    
    // MARK: - Private Helpers
    
    private func encodeBody(parameters: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        
        let pairs = parameters.sorted(by: { $0.key < $1.key }).compactMap { key, value -> String? in
            guard let encKey = key.addingPercentEncoding(withAllowedCharacters: allowed),
                  let encVal = value.addingPercentEncoding(withAllowedCharacters: allowed) else {
                return nil
            }
            return "\(encKey)=\(encVal)"
        }
        
        return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
    }
    
    private func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
            return errorResponse.errorDescription ?? errorResponse.error
        }
        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
            return string
        }
        return "HTTP \(statusCode)"
    }
}

// MARK: - Internal Response DTOs

struct OAuthTokenResponse: Decodable {
    let tokenType: String
    let accessToken: String
    let installationId: String?
    let userId: String?
    let teamId: String?
    let scope: String?
    let expiresIn: Int?
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case accessToken = "access_token"
        case installationId = "installation_id"
        case userId = "user_id"
        case teamId = "team_id"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
