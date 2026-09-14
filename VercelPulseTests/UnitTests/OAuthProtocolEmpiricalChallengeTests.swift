import XCTest
import Security
import CryptoKit
import AppKit
import AuthenticationServices
@testable import VercelPulse

final class OAuthProtocolEmpiricalChallengeTests: XCTestCase {
    
    private var testServiceName: String!
    private var testKeychain: KeychainManager!
    private var mockSession: URLSession!
    private var oauthService: VercelOAuthService!
    private var config: OAuthConfig!
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        mockSession = MockURLProtocol.makeMockSession()
        
        testServiceName = "com.vercelpulse.challenge.oauth.\(UUID().uuidString)"
        testKeychain = KeychainManager(serviceName: testServiceName)
        
        config = OAuthConfig(
            clientId: "test_client_id_123",
            clientSecret: "test_secret_456",
            authorizationEndpoint: URL(string: "https://vercel.com/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://api.vercel.com/v2/oauth/access_token")!,
            redirectURI: "vercelpulse://oauth-callback",
            callbackScheme: "vercelpulse",
            defaultScopes: ["openid", "email"]
        )
        
        oauthService = VercelOAuthService(
            keychainManager: testKeychain,
            session: mockSession,
            config: config
        )
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
        if let keychain = testKeychain {
            try? keychain.purgeAll()
            testKeychain = nil
        }
        oauthService = nil
        super.tearDown()
    }
    
    // MARK: - Group 1: PKCE RFC 7636 Conformance & Mathematical Integrity
    
    func testPKCE_RFC7636_AppendixB_VectorVerification() {
        // RFC 7636 Appendix B test vector
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        
        let computedChallenge = PKCEHelper.computeChallenge(for: verifier)
        XCTAssertEqual(computedChallenge, expectedChallenge, "Challenge calculation must match RFC 7636 Appendix B test vector")
    }
    
    func testPKCE_Generate_EntropyAndLength() throws {
        var generatedVerifiers = Set<String>()
        
        for _ in 0..<100 {
            let pair = try PKCEHelper.generate()
            XCTAssertEqual(pair.codeChallengeMethod, "S256")
            XCTAssertEqual(pair.codeVerifier.count, 43, "Base64URL of 32 bytes should produce 43 characters")
            
            // Check Base64URL character constraints (no +, /, or = padding)
            XCTAssertFalse(pair.codeVerifier.contains("+"))
            XCTAssertFalse(pair.codeVerifier.contains("/"))
            XCTAssertFalse(pair.codeVerifier.contains("="))
            
            XCTAssertFalse(pair.codeChallenge.contains("+"))
            XCTAssertFalse(pair.codeChallenge.contains("/"))
            XCTAssertFalse(pair.codeChallenge.contains("="))
            
            // Challenge must match SHA256 of verifier
            let expectedChallenge = PKCEHelper.computeChallenge(for: pair.codeVerifier)
            XCTAssertEqual(pair.codeChallenge, expectedChallenge)
            
            generatedVerifiers.insert(pair.codeVerifier)
        }
        
        XCTAssertEqual(generatedVerifiers.count, 100, "All 100 randomly generated PKCE verifiers must be distinct")
    }
    
    func testPKCE_GenerateCodeVerifier_LengthClamping() {
        // RFC 7636 min 43, max 128
        let lowClamped = PKCEHelper.generateCodeVerifier(length: 10)
        XCTAssertEqual(lowClamped.count, 43)
        
        let highClamped = PKCEHelper.generateCodeVerifier(length: 300)
        XCTAssertEqual(highClamped.count, 128)
        
        let exact64 = PKCEHelper.generateCodeVerifier(length: 64)
        XCTAssertEqual(exact64.count, 64)
        
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        XCTAssertTrue(exact64.unicodeScalars.allSatisfy { unreserved.contains($0) })
    }
    
    func testPKCE_ComputeChallenge_EdgeCases() {
        // Empty string
        let emptyChallenge = PKCEHelper.computeChallenge(for: "")
        let hash = SHA256.hash(data: Data())
        let expectedBase64Url = Data(hash).base64URLEncodedString()
        XCTAssertEqual(emptyChallenge, expectedBase64Url)
        
        // 128 tildes
        let tildes = String(repeating: "~", count: 128)
        let tildeChallenge = PKCEHelper.computeChallenge(for: tildes)
        XCTAssertFalse(tildeChallenge.isEmpty)
        XCTAssertFalse(tildeChallenge.contains("="))
        
        // Equatable test for PKCEPair
        let pair1 = PKCEPair(codeVerifier: "v1", codeChallenge: "c1", codeChallengeMethod: "S256")
        let pair2 = PKCEPair(codeVerifier: "v1", codeChallenge: "c1", codeChallengeMethod: "S256")
        let pair3 = PKCEPair(codeVerifier: "v2", codeChallenge: "c2", codeChallengeMethod: "S256")
        XCTAssertEqual(pair1, pair2)
        XCTAssertNotEqual(pair1, pair3)
    }
    
    // MARK: - Group 2: OAuthConfig & Authorization URL Assembly
    
    func testOAuthConfig_BuildAuthorizationURL_StandardQuery() throws {
        let pkce = PKCEPair(codeVerifier: "my_verifier", codeChallenge: "my_challenge", codeChallengeMethod: "S256")
        let state = "csrf_test_state_123"
        
        let url = try config.buildAuthorizationURL(state: state, pkce: pkce)
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            XCTFail("Failed to parse built authorization URL")
            return
        }
        
        let items = Dictionary(components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { $1 })
        
        XCTAssertEqual(items["client_id"], "test_client_id_123")
        XCTAssertEqual(items["redirect_uri"], "vercelpulse://oauth-callback")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["state"], "csrf_test_state_123")
        XCTAssertEqual(items["code_challenge"], "my_challenge")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["scope"], "openid email")
    }
    
    func testOAuthConfig_BuildAuthorizationURL_CustomScopes() throws {
        let pkce = PKCEPair(codeVerifier: "v", codeChallenge: "c")
        let url = try config.buildAuthorizationURL(state: "s", pkce: pkce, scopes: ["read:deployments", "write:deployments"])
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scope = components?.queryItems?.first(where: { $0.name == "scope" })?.value
        XCTAssertEqual(scope, "read:deployments write:deployments")
    }
    
    func testOAuthConfig_BuildAuthorizationURL_SpecialCharactersInState() throws {
        let specialState = "state/with+special=chars&more!#$"
        let url = try config.authorizationURL(state: specialState, codeChallenge: "chall")
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        XCTAssertEqual(state, specialState)
    }
    
    // MARK: - Group 3: OAuth Callback URL Parsing & Anti-CSRF State Validation
    
    func testCallbackParser_ValidCallbackExtraction() throws {
        let url = URL(string: "vercelpulse://oauth-callback?code=vcp_auth_code_999&state=state_secret_123&teamId=team_alpha&configurationId=cfg_abc")!
        let result = try OAuthCallbackParser.parse(url: url, expectedState: "state_secret_123")
        
        XCTAssertEqual(result.code, "vcp_auth_code_999")
        XCTAssertEqual(result.state, "state_secret_123")
        XCTAssertEqual(result.teamId, "team_alpha")
        XCTAssertEqual(result.configurationId, "cfg_abc")
    }
    
    func testCallbackParser_StateTamperMismatch_ThrowsError() {
        let url = URL(string: "vercelpulse://oauth-callback?code=vcp_code&state=tampered_attacker_state")!
        
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: url, expectedState: "original_secure_state")) { error in
            guard case OAuthError.stateMismatchDetails(let expected, let received) = error else {
                XCTFail("Expected stateMismatchDetails error, got: \(error)")
                return
            }
            XCTAssertEqual(expected, "original_secure_state")
            XCTAssertEqual(received, "tampered_attacker_state")
        }
    }
    
    func testCallbackParser_MissingState_WhenExpected_ThrowsError() {
        let url = URL(string: "vercelpulse://oauth-callback?code=vcp_code")!
        
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: url, expectedState: "expected_state")) { error in
            guard case OAuthError.stateMismatchDetails(let expected, let received) = error else {
                XCTFail("Expected stateMismatchDetails error, got: \(error)")
                return
            }
            XCTAssertEqual(expected, "expected_state")
            XCTAssertEqual(received, "<missing>")
        }
    }
    
    func testCallbackParser_InvalidScheme_ThrowsError() {
        let httpURL = URL(string: "https://vercel.com/oauth-callback?code=123&state=xyz")!
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: httpURL, expectedState: "xyz")) { error in
            guard case OAuthError.invalidCallbackURL = error else {
                XCTFail("Expected invalidCallbackURL error, got: \(error)")
                return
            }
        }
        
        let customSchemeURL = URL(string: "otherscheme://oauth-callback?code=123&state=xyz")!
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: customSchemeURL, expectedState: "xyz"))
    }
    
    func testCallbackParser_MissingCode_ThrowsError() {
        let missingCodeURL = URL(string: "vercelpulse://oauth-callback?state=xyz")!
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: missingCodeURL, expectedState: "xyz")) { error in
            XCTAssertEqual(error as? OAuthError, .missingAuthorizationCode)
        }
        
        let emptyCodeURL = URL(string: "vercelpulse://oauth-callback?code=&state=xyz")!
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: emptyCodeURL, expectedState: "xyz")) { error in
            XCTAssertEqual(error as? OAuthError, .missingAuthorizationCode)
        }
    }
    
    func testCallbackParser_UserCancelled_AccessDenied() {
        let deniedURL = URL(string: "vercelpulse://oauth-callback?error=access_denied&error_description=The+user+cancelled")!
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: deniedURL, expectedState: nil)) { error in
            XCTAssertEqual(error as? OAuthError, .userCancelled)
        }
    }
    
    func testCallbackParser_ServerError_ThrowsGenericError() {
        let serverErrorURL = URL(string: "vercelpulse://oauth-callback?error=server_error&error_description=Database%20offline")!
        XCTAssertThrowsError(try OAuthCallbackParser.parse(url: serverErrorURL, expectedState: nil)) { error in
            guard case OAuthError.serverError(let err, let desc) = error else {
                XCTFail("Expected serverError, got: \(error)")
                return
            }
            XCTAssertEqual(err, "server_error")
            XCTAssertEqual(desc, "Database offline")
        }
    }
    
    func testCallbackParser_PercentEncodedParameters() throws {
        let url = URL(string: "vercelpulse://oauth-callback?code=code%2B123%2Fxyz&state=state%3Dsecure")!
        let result = try OAuthCallbackParser.parse(url: url, expectedState: "state=secure")
        XCTAssertEqual(result.code, "code+123/xyz")
        XCTAssertEqual(result.state, "state=secure")
    }
    
    func testCallbackParser_DuplicateQueryParameters() throws {
        let url = URL(string: "vercelpulse://oauth-callback?code=first_code&code=second_code&state=st_123")!
        let result = try OAuthCallbackParser.parse(url: url, expectedState: "st_123")
        XCTAssertEqual(result.code, "first_code")
    }
    
    // MARK: - Group 4: OAuth Token Exchange Flow (exchangeCode)
    
    func testOAuthService_ExchangeCode_Success_ParsesAndPersists() async throws {
        let responseJSON = """
        {
            "token_type": "Bearer",
            "access_token": "vcp_tok_access_success_123",
            "refresh_token": "vcp_ref_refresh_success_456",
            "expires_in": 7200,
            "team_id": "team_vercel_prod_42",
            "user_id": "usr_john_doe",
            "scope": "deployments"
        }
        """
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: responseJSON,
            statusCode: 200
        )
        
        let token = try await oauthService.exchangeCode(
            code: "auth_code_abc",
            codeVerifier: "pkce_verifier_xyz",
            redirectURI: "vercelpulse://oauth-callback",
            fallbackTeamId: nil
        )
        
        // 1. Verify returned model
        XCTAssertEqual(token.accessToken, "vcp_tok_access_success_123")
        XCTAssertEqual(token.refreshToken, "vcp_ref_refresh_success_456")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.expiresIn, 7200)
        XCTAssertEqual(token.teamId, "team_vercel_prod_42")
        XCTAssertEqual(token.userId, "usr_john_doe")
        XCTAssertEqual(token.scope, "deployments")
        XCTAssertNotNil(token.expiresAt)
        XCTAssertGreaterThan(token.expiresAt!, Date())
        
        // 2. Verify Keychain persistence
        let stored = testKeychain.getToken()
        XCTAssertEqual(stored?.accessToken, "vcp_tok_access_success_123")
        XCTAssertEqual(stored?.refreshToken, "vcp_ref_refresh_success_456")
        XCTAssertEqual(stored?.teamId, "team_vercel_prod_42")
        
        // 3. Verify UserDefaults teamId
        XCTAssertEqual(UserDefaults.standard.string(forKey: "teamId"), "team_vercel_prod_42")
        
        // 4. Verify outgoing request structure
        let recorded = MockURLProtocol.recordedRequests.first
        XCTAssertEqual(recorded?.httpMethod, "POST")
        XCTAssertEqual(recorded?.allHTTPHeaderFields?["Content-Type"], "application/x-www-form-urlencoded")
        XCTAssertEqual(recorded?.allHTTPHeaderFields?["Accept"], "application/json")
        
        let bodyString = String(data: recorded?.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains("client_id=test_client_id_123"))
        XCTAssertTrue(bodyString.contains("client_secret=test_secret_456"))
        XCTAssertTrue(bodyString.contains("code=auth_code_abc"))
        XCTAssertTrue(bodyString.contains("code_verifier=pkce_verifier_xyz"))
        XCTAssertTrue(bodyString.contains("redirect_uri=vercelpulse%3A%2F%2Foauth-callback"))
        
        // 5. Verify authentication status
        XCTAssertTrue(oauthService.isAuthenticated)
    }
    
    func testOAuthService_ExchangeCode_HTTP400_InvalidGrant() async {
        let errorJSON = """
        {
            "error": "invalid_grant",
            "error_description": "The provided authorization grant is invalid, expired, or revoked"
        }
        """
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: errorJSON,
            statusCode: 400
        )
        
        do {
            _ = try await oauthService.exchangeCode(code: "expired_code", codeVerifier: "verifier")
            XCTFail("Should have thrown tokenExchangeFailed")
        } catch let OAuthError.tokenExchangeFailed(statusCode, message) {
            XCTAssertEqual(statusCode, 400)
            XCTAssertTrue(message.contains("The provided authorization grant is invalid"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_ExchangeCode_HTTP401_Unauthorized() async {
        let errorJSON = """
        {
            "error": "unauthorized_client",
            "error_description": "Client authentication failed"
        }
        """
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: errorJSON,
            statusCode: 401
        )
        
        do {
            _ = try await oauthService.exchangeCode(code: "c", codeVerifier: "v")
            XCTFail("Should have thrown tokenExchangeFailed")
        } catch let OAuthError.tokenExchangeFailed(statusCode, message) {
            XCTAssertEqual(statusCode, 401)
            XCTAssertEqual(message, "Client authentication failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_ExchangeCode_HTTP500_NonJSON() async {
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            response: MockURLProtocol.MockResponse(
                statusCode: 500,
                headers: ["Content-Type": "text/plain"],
                data: "Internal Server Fault 500".data(using: .utf8)
            )
        )
        
        do {
            _ = try await oauthService.exchangeCode(code: "c", codeVerifier: "v")
            XCTFail("Should have thrown tokenExchangeFailed")
        } catch let OAuthError.tokenExchangeFailed(statusCode, message) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(message, "Internal Server Fault 500")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_ExchangeCode_MalformedJSON_ThrowsDecodingError() async {
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: "{\"token_type\": 123, \"access_token\": [\"not_a_string\"]}",
            statusCode: 200
        )
        
        do {
            _ = try await oauthService.exchangeCode(code: "c", codeVerifier: "v")
            XCTFail("Should have thrown decodingError")
        } catch let OAuthError.decodingError(msg) {
            XCTAssertFalse(msg.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_ExchangeCode_NetworkTimeout_ThrowsNetworkError() async {
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            response: MockURLProtocol.MockResponse(error: URLError(.timedOut))
        )
        
        do {
            _ = try await oauthService.exchangeCode(code: "c", codeVerifier: "v")
            XCTFail("Should have thrown networkError")
        } catch let OAuthError.networkError(msg) {
            XCTAssertFalse(msg.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_ExchangeCode_FallbackTeamId_AppliedWhenResponseOmits() async throws {
        let noTeamJSON = """
        {
            "token_type": "Bearer",
            "access_token": "vcp_tok_no_team",
            "expires_in": 3600
        }
        """
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: noTeamJSON,
            statusCode: 200
        )
        
        let token = try await oauthService.exchangeCode(
            code: "c",
            codeVerifier: "v",
            fallbackTeamId: "team_fallback_123"
        )
        
        XCTAssertEqual(token.teamId, "team_fallback_123")
    }
    
    // MARK: - Group 5: OAuth Token Refresh Flow (refreshToken & getValidAccessToken)
    
    func testOAuthService_RefreshToken_Success_UpdatesAndRotates() async throws {
        // Seed initial token
        let initialToken = OAuthToken(
            accessToken: "old_access_token_111",
            refreshToken: "old_refresh_token_222",
            expiresIn: 10,
            teamId: "team_preserved_333",
            userId: "user_preserved_444"
        )
        try testKeychain.saveToken(initialToken)
        
        let refreshResponseJSON = """
        {
            "token_type": "Bearer",
            "access_token": "new_access_token_777",
            "refresh_token": "new_refresh_token_888",
            "expires_in": 86400
        }
        """
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: refreshResponseJSON,
            statusCode: 200
        )
        
        let refreshed = try await oauthService.refreshToken()
        
        // 1. Check returned updated token
        XCTAssertEqual(refreshed.accessToken, "new_access_token_777")
        XCTAssertEqual(refreshed.refreshToken, "new_refresh_token_888")
        XCTAssertEqual(refreshed.expiresIn, 86400)
        XCTAssertEqual(refreshed.teamId, "team_preserved_333", "Must preserve teamId when refresh response omits it")
        XCTAssertEqual(refreshed.userId, "user_preserved_444", "Must preserve userId when refresh response omits it")
        
        // 2. Check Keychain has updated token
        let stored = testKeychain.getToken()
        XCTAssertEqual(stored?.accessToken, "new_access_token_777")
        XCTAssertEqual(stored?.refreshToken, "new_refresh_token_888")
        
        // 3. Check outgoing request
        let req = MockURLProtocol.recordedRequests.first
        let body = String(data: req?.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("grant_type=refresh_token"))
        XCTAssertTrue(body.contains("refresh_token=old_refresh_token_222"))
        XCTAssertTrue(body.contains("client_id=test_client_id_123"))
    }
    
    func testOAuthService_RefreshToken_MissingStoredToken_ThrowsMissingToken() async {
        do {
            _ = try await oauthService.refreshToken()
            XCTFail("Should have thrown missingToken")
        } catch let error as OAuthError {
            XCTAssertEqual(error, .missingToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_RefreshToken_MissingRefreshToken_ThrowsMissingRefreshToken() async throws {
        let patToken = OAuthToken(accessToken: "pat_without_refresh")
        try testKeychain.saveToken(patToken)
        
        do {
            _ = try await oauthService.refreshToken()
            XCTFail("Should have thrown missingRefreshToken")
        } catch let error as OAuthError {
            XCTAssertEqual(error, .missingRefreshToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_RefreshToken_ExpiredRefreshToken_HTTP400_ThrowsError() async throws {
        let token = OAuthToken(accessToken: "tok", refreshToken: "bad_ref")
        try testKeychain.saveToken(token)
        
        let errorJSON = """
        {
            "error": "invalid_grant",
            "error_description": "Refresh token is invalid or expired"
        }
        """
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: errorJSON,
            statusCode: 400
        )
        
        do {
            _ = try await oauthService.refreshToken()
            XCTFail("Should have thrown tokenRefreshFailed")
        } catch let OAuthError.tokenRefreshFailed(statusCode, message) {
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(message, "Refresh token is invalid or expired")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOAuthService_GetValidAccessToken_ReturnsCurrentWhenFresh() async throws {
        // Token fresh for 1 hour
        let freshToken = OAuthToken(
            accessToken: "fresh_access_token_999",
            refreshToken: "ref_999",
            expiresIn: 3600,
            expiresAt: Date().addingTimeInterval(3600)
        )
        try testKeychain.saveToken(freshToken)
        
        let validToken = try await oauthService.getValidAccessToken()
        XCTAssertEqual(validToken, "fresh_access_token_999")
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 0, "Should not make any network requests when token is fresh")
    }
    
    func testOAuthService_GetValidAccessToken_ProactivelyRefreshesWhenExpiringIn45Seconds() async throws {
        // Token expiring in 45 seconds (threshold is <= 60s)
        let soonExpiringToken = OAuthToken(
            accessToken: "expiring_soon_token",
            refreshToken: "ref_soon",
            expiresIn: 45,
            expiresAt: Date().addingTimeInterval(45)
        )
        try testKeychain.saveToken(soonExpiringToken)
        
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: """
            {
                "token_type": "Bearer",
                "access_token": "renewed_access_token_auto",
                "refresh_token": "renewed_refresh_token_auto",
                "expires_in": 86400
            }
            """,
            statusCode: 200
        )
        
        let validToken = try await oauthService.getValidAccessToken()
        XCTAssertEqual(validToken, "renewed_access_token_auto")
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1, "Must proactively perform refresh request")
    }
    
    func testOAuthService_GetValidAccessToken_ProactivelyRefreshesWhenAlreadyExpired() async throws {
        let expiredToken = OAuthToken(
            accessToken: "already_expired_tok",
            refreshToken: "ref_expired",
            expiresIn: -100,
            expiresAt: Date().addingTimeInterval(-100)
        )
        try testKeychain.saveToken(expiredToken)
        
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: """
            {
                "token_type": "Bearer",
                "access_token": "renewed_after_expired",
                "refresh_token": "renewed_ref",
                "expires_in": 86400
            }
            """,
            statusCode: 200
        )
        
        let validToken = try await oauthService.getValidAccessToken()
        XCTAssertEqual(validToken, "renewed_after_expired")
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1)
    }
    
    func testOAuthService_GetValidAccessToken_ThrowsWhenUnauthenticated() async {
        do {
            _ = try await oauthService.getValidAccessToken()
            XCTFail("Should throw missingToken")
        } catch let error as OAuthError {
            XCTAssertEqual(error, .missingToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Group 6: Concurrency, Deduplication, & Race Conditions
    
    func testOAuthService_ConcurrentRefreshDeduplication_10Threads() async throws {
        let token = OAuthToken(
            accessToken: "tok_concurrency",
            refreshToken: "ref_concurrency",
            expiresIn: 10,
            expiresAt: Date().addingTimeInterval(10) // Expiring soon
        )
        try testKeychain.saveToken(token)
        
        // Stub refresh with a slight delay to simulate network latency
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            response: MockURLProtocol.MockResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                data: """
                {
                    "token_type": "Bearer",
                    "access_token": "deduped_shared_token_999",
                    "refresh_token": "deduped_shared_ref_999",
                    "expires_in": 86400
                }
                """.data(using: .utf8),
                delay: 0.05
            )
        )
        
        // Launch 10 concurrent tasks all calling refreshToken() simultaneously
        let results = try await withThrowingTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let refreshed = try await self.oauthService.refreshToken()
                    return refreshed.accessToken
                }
            }
            
            var collected: [String] = []
            for try await tokenString in group {
                collected.append(tokenString)
            }
            return collected
        }
        
        XCTAssertEqual(results.count, 10)
        XCTAssertTrue(results.allSatisfy { $0 == "deduped_shared_token_999" })
        
        // Exactly 1 network request must have been made due to task deduplication
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1, "Concurrency deduplication must collapse 10 simultaneous refresh requests into exactly 1 HTTP POST")
    }
    
    func testOAuthService_ConcurrentRefreshFailure_CleansUpTaskAndAllowsRetry() async throws {
        let token = OAuthToken(accessToken: "tok", refreshToken: "ref", expiresIn: 10)
        try testKeychain.saveToken(token)
        
        // 1. First attempt fails
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            response: MockURLProtocol.MockResponse(error: URLError(.networkConnectionLost))
        )
        
        do {
            _ = try await oauthService.refreshToken()
            XCTFail("Should have failed with networkError")
        } catch let OAuthError.networkError(msg) {
            XCTAssertFalse(msg.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // 2. Second attempt succeeds (verifies refreshTask was cleaned up and does not hang on old failed task)
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: """
            {
                "token_type": "Bearer",
                "access_token": "retry_success_token",
                "refresh_token": "retry_ref",
                "expires_in": 3600
            }
            """,
            statusCode: 200
        )
        
        let retryToken = try await oauthService.refreshToken()
        XCTAssertEqual(retryToken.accessToken, "retry_success_token")
    }
    
    // MARK: - Group 7: Manual PAT, Logout & Session Purge
    
    func testOAuthService_SavePersonalAccessToken_Success() throws {
        try oauthService.savePersonalAccessToken("  pat_manual_secret_key_123  ", teamId: "team_personal_prod")
        
        XCTAssertTrue(oauthService.isAuthenticated)
        
        let stored = testKeychain.getToken()
        XCTAssertEqual(stored?.accessToken, "pat_manual_secret_key_123")
        XCTAssertNil(stored?.refreshToken)
        XCTAssertEqual(stored?.tokenType, "Bearer")
        XCTAssertEqual(stored?.teamId, "team_personal_prod")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "teamId"), "team_personal_prod")
    }
    
    func testOAuthService_SavePersonalAccessToken_EmptyThrowsMissingToken() {
        XCTAssertThrowsError(try oauthService.savePersonalAccessToken("   \n\t   ")) { error in
            XCTAssertEqual(error as? OAuthError, .missingToken)
        }
    }
    
    func testOAuthService_Logout_PurgesKeychainAndUserDefaults() throws {
        // Setup initial authenticated state
        try oauthService.savePersonalAccessToken("pat_test_logout", teamId: "team_to_clear")
        XCTAssertTrue(oauthService.isAuthenticated)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "teamId"), "team_to_clear")
        
        // Execute logout
        try oauthService.logout()
        
        // Verify purged state
        XCTAssertFalse(oauthService.isAuthenticated)
        XCTAssertNil(oauthService.currentToken)
        XCTAssertNil(testKeychain.getToken())
        XCTAssertNil(UserDefaults.standard.string(forKey: "teamId"))
    }
    
    // MARK: - Group 8: AuthPresentationContextProvider Multi-Tier Fallback
    
    func testAuthPresentationContextProvider_MultiTierAnchorResolution() {
        let provider = AuthPresentationContextProvider.shared
        
        // Should safely return an NSWindow (either keyWindow, visible window, or headless dummy) without crashing
        let dummySession = ASWebAuthenticationSession(
            url: URL(string: "https://vercel.com")!,
            callbackURLScheme: "vercelpulse",
            completionHandler: { _, _ in }
        )
        
        let anchor = provider.presentationAnchor(for: dummySession)
        XCTAssertNotNil(anchor)
        XCTAssertTrue(anchor.isKind(of: NSWindow.self))
        
        // Cleanup should not throw or crash
        provider.cleanUpFallbackWindow()
    }
}
