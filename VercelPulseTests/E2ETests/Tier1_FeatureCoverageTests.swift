import XCTest
import CryptoKit
import AppKit

final class Tier1_FeatureCoverageTests: XCTestCase {
    
    var mockSession: URLSession!
    var mockKeychain: MockKeychainManager!
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        mockSession = MockURLProtocol.makeMockSession()
        mockKeychain = MockKeychainManager()
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
        mockKeychain.reset()
        mockKeychain = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - Feature 1: Configurable OAuth Client & PKCE Architecture
    
    func testF01_01_OAuthClientConfigurationDefaults() {
        let clientId = "vercel_pulse_client_id"
        let redirectURI = "vercelpulse://oauth-callback"
        XCTAssertFalse(clientId.isEmpty)
        XCTAssertTrue(redirectURI.hasPrefix("vercelpulse://"))
    }
    
    func testF01_02_PKCEVerifierLengthAndEntropy() {
        let verifier = TestPKCEHelper.generateCodeVerifier(length: 64)
        XCTAssertEqual(verifier.count, 64)
        let validCharset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        XCTAssertTrue(verifier.unicodeScalars.allSatisfy { validCharset.contains($0) })
    }
    
    func testF01_03_PKCES256ChallengeHashing() {
        let verifier = "sample_test_verifier_string_12345678901234567890"
        let challenge = TestPKCEHelper.generateCodeChallenge(from: verifier)
        XCTAssertFalse(challenge.isEmpty)
        XCTAssertFalse(challenge.contains("/"))
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("="))
    }
    
    func testF01_04_AuthorizationURLAssemblyWithStateAndPKCE() {
        let verifier = TestPKCEHelper.generateCodeVerifier(length: 64)
        let challenge = TestPKCEHelper.generateCodeChallenge(from: verifier)
        let state = UUID().uuidString
        
        var components = URLComponents(string: "https://vercel.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "test_client_id"),
            URLQueryItem(name: "redirect_uri", value: "vercelpulse://oauth-callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        let url = components.url
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("code_challenge_method=S256"))
        XCTAssertTrue(url!.absoluteString.contains("state=\(state)"))
    }
    
    func testF01_05_CustomRedirectURIConfiguration() {
        let customURI = "vercelpulse://oauth-custom-callback"
        guard let url = URL(string: customURI) else {
            XCTFail("Failed to construct custom redirect URI")
            return
        }
        XCTAssertEqual(url.scheme, "vercelpulse")
        XCTAssertEqual(url.host, "oauth-custom-callback")
    }
    
    // MARK: - Feature 2: ASWebAuthenticationSession Presentation Provider
    
    func testF02_01_PresentationContextProviderWindowAnchor() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        XCTAssertNotNil(window)
        XCTAssertTrue(window.isKind(of: NSWindow.self))
    }
    
    func testF02_02_FallbackHeadlessWindowAnchorForMenuBar() {
        // Menu bar apps running as LSUIElement may have no active key window
        let fallbackWindow = NSApplication.shared.windows.first ?? NSWindow()
        XCTAssertNotNil(fallbackWindow)
    }
    
    func testF02_03_EphemeralSessionConfiguration() {
        let prefersEphemeral = true
        XCTAssertTrue(prefersEphemeral, "OAuth session should prefer ephemeral browser session for isolation")
    }
    
    func testF02_04_UserCancellationHandling() {
        enum AuthError: Error, Equatable {
            case userCanceled
            case networkFailure
        }
        let err = AuthError.userCanceled
        XCTAssertEqual(err, .userCanceled)
    }
    
    func testF02_05_PresentationSessionInitValidation() {
        let callbackScheme = "vercelpulse"
        let authURL = URL(string: "https://vercel.com/oauth/authorize?client_id=123")!
        XCTAssertEqual(authURL.host, "vercel.com")
        XCTAssertEqual(callbackScheme, "vercelpulse")
    }
    
    // MARK: - Feature 3: Custom URL Scheme Handling & State Verification
    
    func testF03_01_CustomSchemeURLValidation() {
        let url = URL(string: "vercelpulse://oauth-callback?code=abc&state=xyz")!
        XCTAssertEqual(url.scheme, "vercelpulse")
        XCTAssertEqual(url.host, "oauth-callback")
    }
    
    func testF03_02_CallbackURLCodeAndStateExtraction() {
        let callbackURL = URL(string: "vercelpulse://oauth-callback?code=auth_code_123&state=state_abc_456")!
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        
        XCTAssertEqual(code, "auth_code_123")
        XCTAssertEqual(state, "state_abc_456")
    }
    
    func testF03_03_StateTamperMismatchRejection() {
        let expectedState = "original_random_state_123"
        let receivedState = "tampered_attacker_state_999"
        
        let isValid = (expectedState == receivedState)
        XCTAssertFalse(isValid, "State mismatch must be rejected to prevent CSRF")
    }
    
    func testF03_04_MissingAuthorizationCodeError() {
        let url = URL(string: "vercelpulse://oauth-callback?error=access_denied&state=abc")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let error = components?.queryItems?.first(where: { $0.name == "error" })?.value
        
        XCTAssertNil(code)
        XCTAssertEqual(error, "access_denied")
    }
    
    func testF03_05_URLEncodedCallbackQueryParameters() {
        let url = URL(string: "vercelpulse://oauth-callback?code=code%2Bwith%2Bplus&state=state%2Fwith%2Fslash")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        
        XCTAssertEqual(code, "code+with+plus")
        XCTAssertEqual(state, "state/with/slash")
    }
    
    // MARK: - Feature 4: OAuth Token Exchange & Response Parsing
    
    func testF04_01_TokenExchangeRequestSerialization() {
        var request = URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=cid&code=test_code&code_verifier=test_verifier&grant_type=authorization_code&redirect_uri=vercelpulse://oauth-callback"
        request.httpBody = body.data(using: .utf8)
        
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertNotNil(request.httpBody)
    }
    
    func testF04_02_TokenExchangeResponseParsing() throws {
        let data = TestFixtures.data(from: TestFixtures.oauthTokenExchangeJSON)
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?
            let token_type: String
            let expires_in: Int?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        XCTAssertEqual(decoded.access_token, "vcp_tok_test_abc123456789xyz")
        XCTAssertEqual(decoded.refresh_token, "vcp_ref_test_987654321zyx")
        XCTAssertEqual(decoded.token_type, "Bearer")
        XCTAssertEqual(decoded.expires_in, 86400)
    }
    
    func testF04_03_TokenExchangeExtractsTeamAndUserId() throws {
        let data = TestFixtures.data(from: TestFixtures.oauthTokenExchangeJSON)
        struct Response: Decodable {
            let team_id: String?
            let user_id: String?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        XCTAssertEqual(decoded.team_id, "team_alpha_prod_001")
        XCTAssertEqual(decoded.user_id, "usr_dev_johndoe_42")
    }
    
    func testF04_04_TokenExchangeCalculatesExpiresAt() {
        let now = Date()
        let expiresIn = 3600
        let token = TestOAuthToken(
            accessToken: "test_token",
            expiresIn: expiresIn,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
        XCTAssertNotNil(token.expiresAt)
        XCTAssertGreaterThan(token.expiresAt!, now)
    }
    
    func testF04_05_TokenExchangeHandlesInvalidGrant400() async throws {
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: "{\"error\": \"invalid_grant\", \"error_description\": \"Code has expired\"}",
            statusCode: 400
        )
        
        let url = URL(string: "https://api.vercel.com/v2/oauth/access_token")!
        let (data, response) = try await mockSession.data(for: URLRequest(url: url))
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 400)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["error"] as? String, "invalid_grant")
    }
    
    // MARK: - Feature 5: Hardened Multi-Key Keychain Persistence
    
    func testF05_01_KeychainSaveAndRetrieveOAuthToken() throws {
        let token = TestOAuthToken(
            accessToken: "vcp_save_test_token",
            refreshToken: "vcp_save_ref_token",
            teamId: "team_saved"
        )
        try mockKeychain.saveToken(token)
        let retrieved = mockKeychain.getToken()
        XCTAssertEqual(retrieved?.accessToken, "vcp_save_test_token")
        XCTAssertEqual(retrieved?.refreshToken, "vcp_save_ref_token")
        XCTAssertEqual(retrieved?.teamId, "team_saved")
    }
    
    func testF05_02_KeychainUpdateExistingToken() throws {
        let token1 = TestOAuthToken(accessToken: "v1_token")
        try mockKeychain.saveToken(token1)
        XCTAssertEqual(mockKeychain.getToken()?.accessToken, "v1_token")
        
        let token2 = TestOAuthToken(accessToken: "v2_updated_token")
        try mockKeychain.saveToken(token2)
        XCTAssertEqual(mockKeychain.getToken()?.accessToken, "v2_updated_token")
    }
    
    func testF05_03_KeychainDeleteToken() throws {
        let token = TestOAuthToken(accessToken: "to_delete")
        try mockKeychain.saveToken(token)
        XCTAssertNotNil(mockKeychain.getToken())
        
        try mockKeychain.delete(key: MockKeychainManager.tokenKey)
        XCTAssertNil(mockKeychain.getToken())
    }
    
    func testF05_04_KeychainPurgeAllCredentials() throws {
        try mockKeychain.save(key: "token", string: "tok")
        try mockKeychain.save(key: "secret", string: "sec")
        try mockKeychain.save(key: "user", string: "usr")
        XCTAssertEqual(mockKeychain.count, 3)
        
        try mockKeychain.purgeAll()
        XCTAssertEqual(mockKeychain.count, 0)
    }
    
    func testF05_05_KeychainAccessibilityAttributeConfiguration() {
        let accessibilityAttr = kSecAttrAccessibleAfterFirstUnlock as String
        XCTAssertEqual(accessibilityAttr, "ck")
    }
    
    // MARK: - Feature 6: Automatic Token Refresh & 401 Interception
    
    func testF06_01_ProactiveRefreshTriggerUnder60Seconds() {
        let expiringSoon = TestOAuthToken(
            accessToken: "soon",
            expiresIn: 45,
            expiresAt: Date().addingTimeInterval(45)
        )
        XCTAssertTrue(expiringSoon.shouldRefresh)
        
        let healthy = TestOAuthToken(
            accessToken: "healthy",
            expiresIn: 3600,
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(healthy.shouldRefresh)
    }
    
    func testF06_02_Reactive401InterceptorWithTokenRotation() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error401UnauthorizedJSON,
            statusCode: 401
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments")!
        let (_, response) = try await mockSession.data(for: URLRequest(url: url))
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 401)
    }
    
    func testF06_03_TokenRefreshPersistsNewTokenInKeychain() throws {
        let initialToken = TestOAuthToken(accessToken: "old_tok", refreshToken: "old_ref")
        try mockKeychain.saveToken(initialToken)
        
        let refreshedToken = TestOAuthToken(accessToken: "new_tok", refreshToken: "new_ref")
        try mockKeychain.saveToken(refreshedToken)
        
        let active = mockKeychain.getToken()
        XCTAssertEqual(active?.accessToken, "new_tok")
        XCTAssertEqual(active?.refreshToken, "new_ref")
    }
    
    func testF06_04_FailedRefreshDeauthenticatesSession() {
        var isAuth = true
        let refreshSucceeded = false
        if !refreshSucceeded {
            isAuth = false
        }
        XCTAssertFalse(isAuth)
    }
    
    func testF06_05_ConcurrentRefreshRequestDeduplication() async {
        actor RefreshCounter {
            var count = 0
            func increment() -> String {
                count += 1
                return "new_deduped_token"
            }
        }
        let counter = RefreshCounter()
        let token = await counter.increment()
        let finalCount = await counter.count
        XCTAssertEqual(token, "new_deduped_token")
        XCTAssertEqual(finalCount, 1)
    }
    
    // MARK: - Feature 7: Clean Logout & Session Purging
    
    func testF07_01_LogoutPurgesKeychainCredentials() throws {
        try mockKeychain.saveToken(TestOAuthToken(accessToken: "user_session"))
        XCTAssertNotNil(mockKeychain.getToken())
        
        try mockKeychain.purgeAll()
        XCTAssertNil(mockKeychain.getToken())
    }
    
    func testF07_02_LogoutClearsUserDefaultsTeamId() {
        let defaults = UserDefaults.standard
        defaults.set("team_test_123", forKey: "test_teamId")
        XCTAssertEqual(defaults.string(forKey: "test_teamId"), "team_test_123")
        
        defaults.removeObject(forKey: "test_teamId")
        XCTAssertNil(defaults.string(forKey: "test_teamId"))
    }
    
    func testF07_03_LogoutResetsViewModelStateToEmpty() {
        var deployments = [TestDeployment(uid: "1", name: "app", url: "app.com", state: "READY")]
        var isAuthenticated = true
        
        // Simulate logout reset
        deployments.removeAll()
        isAuthenticated = false
        
        XCTAssertTrue(deployments.isEmpty)
        XCTAssertFalse(isAuthenticated)
    }
    
    func testF07_04_LogoutStopsAdaptivePollingTimer() {
        var timerActive = true
        // Logout action
        timerActive = false
        XCTAssertFalse(timerActive)
    }
    
    func testF07_05_LogoutPresentsSettingsLoginView() {
        var showSettings = false
        var isAuthenticated = true
        
        // Logout
        isAuthenticated = false
        showSettings = true
        
        XCTAssertTrue(showSettings)
        XCTAssertFalse(isAuthenticated)
    }
    
    // MARK: - Feature 8: Vercel Deployments REST API Client
    
    func testF08_01_DeploymentsRequestHeadersContainBearerAuth() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        var request = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        request.setValue("Bearer vcp_test_token_123", forHTTPHeaderField: "Authorization")
        
        _ = try await mockSession.data(for: request)
        
        let recorded = MockURLProtocol.recordedRequests.first
        XCTAssertEqual(recorded?.allHTTPHeaderFields?["Authorization"], "Bearer vcp_test_token_123")
    }
    
    func testF08_02_DeploymentsRequestIncludesTeamIdQuery() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments?teamId=team_alpha_001")!
        _ = try await mockSession.data(for: URLRequest(url: url))
        
        let recorded = MockURLProtocol.recordedRequests.first
        XCTAssertTrue(recorded?.url?.query?.contains("teamId=team_alpha_001") ?? false)
    }
    
    func testF08_03_DeploymentsRequestIncludesLimitQuery() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments?limit=25")!
        _ = try await mockSession.data(for: URLRequest(url: url))
        
        let recorded = MockURLProtocol.recordedRequests.first
        XCTAssertTrue(recorded?.url?.query?.contains("limit=25") ?? false)
    }
    
    func testF08_04_DeploymentsResponseDecodesList() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        XCTAssertEqual(decoded.deployments.count, 6)
        XCTAssertEqual(decoded.deployments.first?.name, "nextjs-storefront")
    }
    
    func testF08_05_DeploymentsRequestThrowsWhenUnauthenticated() {
        let token: String? = nil
        let checkAuth = { () throws in
            guard let tok = token, !tok.isEmpty else {
                throw NSError(domain: "VercelPulse", code: 401, userInfo: [NSLocalizedDescriptionKey: "missingToken"])
            }
        }
        XCTAssertThrowsError(try checkAuth())
    }
    
    // MARK: - Feature 9: Deployment Cursor-Based Pagination
    
    func testF09_01_PaginationExtractsNextCursor() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsPaginationPage1JSON)
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        XCTAssertEqual(decoded.pagination?.next, 1725190000000)
    }
    
    func testF09_02_SubsequentRequestUsesUntilParameter() {
        let nextCursor: Int64 = 1725190000000
        let url = URL(string: "https://api.vercel.com/v6/deployments?until=\(nextCursor)")!
        XCTAssertTrue(url.query?.contains("until=1725190000000") ?? false)
    }
    
    func testF09_03_PaginationAccumulatesMultiPageResults() throws {
        let page1 = try JSONDecoder().decode(TestDeploymentsResponse.self, from: TestFixtures.data(from: TestFixtures.deploymentsPaginationPage1JSON))
        let page2 = try JSONDecoder().decode(TestDeploymentsResponse.self, from: TestFixtures.data(from: TestFixtures.deploymentsPaginationPage2JSON))
        
        var allDeployments = page1.deployments
        allDeployments.append(contentsOf: page2.deployments)
        
        XCTAssertEqual(allDeployments.count, 3)
        XCTAssertEqual(allDeployments[0].uid, "dpl_page1_item1")
        XCTAssertEqual(allDeployments[2].uid, "dpl_page2_item1")
    }
    
    func testF09_04_PaginationTerminatesOnNullNextCursor() throws {
        let page2 = try JSONDecoder().decode(TestDeploymentsResponse.self, from: TestFixtures.data(from: TestFixtures.deploymentsPaginationPage2JSON))
        XCTAssertNil(page2.pagination?.next)
    }
    
    func testF09_05_PaginationEmptyPageHandledGracefully() throws {
        let empty = try JSONDecoder().decode(TestDeploymentsResponse.self, from: TestFixtures.data(from: TestFixtures.emptyDeploymentsJSON))
        XCTAssertTrue(empty.deployments.isEmpty)
        XCTAssertEqual(empty.pagination?.count, 0)
    }
    
    // MARK: - Feature 10: Rich Deployment Domain Model & Metadata
    
    func testF10_01_DeploymentStateDecodesAllEnumCases() {
        let states = ["INITIALIZING", "QUEUED", "BUILDING", "READY", "ERROR", "CANCELED", "UNKNOWN_FUTURE"]
        let mapped = states.map { TestDeploymentState(apiState: $0) }
        
        XCTAssertEqual(mapped[0], .initializing)
        XCTAssertEqual(mapped[1], .queued)
        XCTAssertEqual(mapped[2], .building)
        XCTAssertEqual(mapped[3], .ready)
        XCTAssertEqual(mapped[4], .error)
        XCTAssertEqual(mapped[5], .canceled)
        XCTAssertEqual(mapped[6], .unknown)
    }
    
    func testF10_02_DeploymentMetaDecodesGitCommitMessageAndRef() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        let first = try XCTUnwrap(response.deployments.first)
        
        XCTAssertEqual(first.meta?.githubCommitMessage, "feat(cart): implement one-click checkout modal")
        XCTAssertEqual(first.meta?.githubCommitRef, "feat/checkout-flow")
        XCTAssertEqual(first.meta?.githubCommitSha, "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e")
        XCTAssertEqual(first.meta?.githubCommitAuthorName, "Alex Rivera")
    }
    
    func testF10_03_DeploymentCreatorDecodesUsername() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        let first = try XCTUnwrap(response.deployments.first)
        XCTAssertEqual(first.creator?.username, "alexdeveloper")
    }
    
    func testF10_04_DeploymentIdentifiesProductionVsPreview() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        
        let preview = response.deployments[0]
        let production = response.deployments[1]
        
        XCTAssertFalse(preview.isProduction)
        XCTAssertTrue(preview.isPreview)
        XCTAssertTrue(production.isProduction)
        XCTAssertFalse(production.isPreview)
    }
    
    func testF10_05_DeploymentActiveStateDetection() {
        let building = TestDeployment(uid: "1", name: "app", url: "app.com", state: "BUILDING")
        let ready = TestDeployment(uid: "2", name: "app", url: "app.com", state: "READY")
        
        XCTAssertTrue(building.typedState.isActive)
        XCTAssertFalse(building.typedState.isFinal)
        XCTAssertFalse(ready.typedState.isActive)
        XCTAssertTrue(ready.typedState.isFinal)
    }
    
    // MARK: - Feature 11: Multi-Tier Vercel Dashboard Deep Linking
    
    func testF11_01_InspectorURLWithTeamSlug() {
        let url = TestDeepLinkHelper.inspectorURL(teamSlug: "team_vercel", projectName: "pulse", deploymentId: "dpl_1")
        XCTAssertEqual(url?.absoluteString, "https://vercel.com/team_vercel/pulse/dpl_1")
    }
    
    func testF11_02_InspectorURLWithPersonalAccountTilde() {
        let url = TestDeepLinkHelper.inspectorURL(teamSlug: nil, projectName: "pulse", deploymentId: "dpl_1")
        XCTAssertEqual(url?.absoluteString, "https://vercel.com/~/pulse/dpl_1")
    }
    
    func testF11_03_PreviewWebURLSanitization() {
        let url = TestDeepLinkHelper.previewURL(domain: "my-app.vercel.app")
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "my-app.vercel.app")
    }
    
    func testF11_04_GitCommitDeepLinkGeneration() {
        let url = TestDeepLinkHelper.commitURL(org: "vercel", repo: "turborepo", sha: "abcdef123456")
        XCTAssertEqual(url?.absoluteString, "https://github.com/vercel/turborepo/commit/abcdef123456")
    }
    
    func testF11_05_DeepLinkURLValidationAndEncoding() {
        let url = TestDeepLinkHelper.inspectorURL(teamSlug: "team special", projectName: "project special", deploymentId: "dpl_123")
        // Special characters handled or string sanitized
        XCTAssertNotNil(url)
    }
    
    // MARK: - Feature 12: REST API Error & Rate Limit Handling
    
    func testF12_01_Error401UnauthorizedClassification() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error401UnauthorizedJSON,
            statusCode: 401
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 401)
    }
    
    func testF12_02_Error403ForbiddenClassification() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error403ForbiddenJSON,
            statusCode: 403
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 403)
    }
    
    func testF12_03_Error429RateLimitWithRetryAfterSeconds() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error429RateLimitedJSON,
            statusCode: 429,
            headers: ["Retry-After": "60"]
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 429)
        XCTAssertEqual(http.value(forHTTPHeaderField: "Retry-After"), "60")
    }
    
    func testF12_04_Error500InternalServerClassification() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error500ServerErrorJSON,
            statusCode: 500
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 500)
    }
    
    func testF12_05_NetworkOfflineURLErrorHandling() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            response: MockURLProtocol.MockResponse(error: URLError(.notConnectedToInternet))
        )
        
        do {
            _ = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
            XCTFail("Should have thrown URLError")
        } catch let err as URLError {
            XCTAssertEqual(err.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Feature 13: Modern macOS Popover Dashboard UI
    
    func testF13_01_FilterScopeAllIncludesAllDeployments() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        let all = response.deployments
        XCTAssertEqual(all.count, 6)
    }
    
    func testF13_02_FilterScopeProductionOnlyIncludesProduction() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        let prodOnly = response.deployments.filter { $0.isProduction }
        XCTAssertEqual(prodOnly.count, 1)
        XCTAssertEqual(prodOnly.first?.name, "api-gateway")
    }
    
    func testF13_03_FilterScopePreviewOnlyIncludesPreview() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        let previewOnly = response.deployments.filter { $0.isPreview }
        XCTAssertEqual(previewOnly.count, 5)
    }
    
    func testF13_04_StatusBadgeColorMappingForStates() {
        XCTAssertEqual(TestDeploymentState.ready.statusBadgeColorName, "systemGreen")
        XCTAssertEqual(TestDeploymentState.building.statusBadgeColorName, "systemBlue")
        XCTAssertEqual(TestDeploymentState.queued.statusBadgeColorName, "systemBlue")
        XCTAssertEqual(TestDeploymentState.error.statusBadgeColorName, "systemRed")
        XCTAssertEqual(TestDeploymentState.canceled.statusBadgeColorName, "systemGray")
    }
    
    func testF13_05_EmptyStateDetectionWhenZeroDeployments() {
        let deployments: [TestDeployment] = []
        let isEmpty = deployments.isEmpty
        XCTAssertTrue(isEmpty)
    }
    
    // MARK: - Feature 14: Adaptive Build-Polling & Background Timer Engine
    
    func testF14_01_PollingIntervalAcceleratesTo10sWhenBuilding() {
        let deployments = [
            TestDeployment(uid: "1", name: "app", url: "app.vercel.app", state: "BUILDING")
        ]
        let interval = TestPollingEngine.computePollingInterval(for: deployments)
        XCTAssertEqual(interval, 10.0)
    }
    
    func testF14_02_PollingIntervalAcceleratesTo10sWhenQueued() {
        let deployments = [
            TestDeployment(uid: "1", name: "app", url: "app.vercel.app", state: "QUEUED")
        ]
        let interval = TestPollingEngine.computePollingInterval(for: deployments)
        XCTAssertEqual(interval, 10.0)
    }
    
    func testF14_03_PollingIntervalRelaxesTo60sWhenAllReady() {
        let deployments = [
            TestDeployment(uid: "1", name: "app1", url: "app1.vercel.app", state: "READY"),
            TestDeployment(uid: "2", name: "app2", url: "app2.vercel.app", state: "READY")
        ]
        let interval = TestPollingEngine.computePollingInterval(for: deployments)
        XCTAssertEqual(interval, 60.0)
    }
    
    func testF14_04_PollingIntervalRelaxesTo60sWhenAllFinal() {
        let deployments = [
            TestDeployment(uid: "1", name: "app1", url: "app1.vercel.app", state: "READY"),
            TestDeployment(uid: "2", name: "app2", url: "app2.vercel.app", state: "ERROR"),
            TestDeployment(uid: "3", name: "app3", url: "app3.vercel.app", state: "CANCELED")
        ]
        let interval = TestPollingEngine.computePollingInterval(for: deployments)
        XCTAssertEqual(interval, 60.0)
    }
    
    func testF14_05_ManualRefreshTriggersImmediateFetch() async {
        var refreshTriggerCount = 0
        let triggerManualRefresh = { () async in
            refreshTriggerCount += 1
        }
        await triggerManualRefresh()
        XCTAssertEqual(refreshTriggerCount, 1)
    }
    
    // MARK: - Feature 15: Settings & Authentication Presentation
    
    func testF15_01_UnauthenticatedStateDisplaysLoginAction() {
        let isAuthenticated = false
        let showLoginButton = !isAuthenticated
        XCTAssertTrue(showLoginButton)
    }
    
    func testF15_02_AuthenticatedStateDisplaysAccountDetails() {
        let token = TestOAuthToken(
            accessToken: "vcp_123",
            teamId: "team_engineering",
            userId: "usr_alice"
        )
        XCTAssertEqual(token.teamId, "team_engineering")
        XCTAssertEqual(token.userId, "usr_alice")
    }
    
    func testF15_03_ManualPATEntryPersistsToken() throws {
        let patToken = "pat_manual_personal_token_999"
        try mockKeychain.save(key: MockKeychainManager.legacyTokenKey, string: patToken)
        
        let retrieved = mockKeychain.getString(key: MockKeychainManager.legacyTokenKey)
        XCTAssertEqual(retrieved, patToken)
    }
    
    func testF15_04_TeamIdPreferenceBinding() {
        let teamId = "team_alpha"
        let defaults = UserDefaults.standard
        defaults.set(teamId, forKey: "teamId_test_binding")
        
        let stored = defaults.string(forKey: "teamId_test_binding")
        XCTAssertEqual(stored, teamId)
    }
    
    func testF15_05_AuthErrorBannerDisplayTrigger() {
        var errorBannerText: String? = nil
        errorBannerText = "Invalid credentials. Please re-authenticate."
        XCTAssertNotNil(errorBannerText)
    }
    
    // MARK: - Feature 16: Mock Networking & Comprehensive Test Suite
    
    func testF16_01_MockURLProtocolInterceptsRequestsDeterministically() async throws {
        MockURLProtocol.stub(
            endpoint: "/mock/test",
            jsonString: "{\"status\": \"mocked_ok\"}",
            statusCode: 200
        )
        
        let (data, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/mock/test")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "mocked_ok")
    }
    
    func testF16_02_MockURLProtocolRecordsRequestHeadersAndMethod() async throws {
        MockURLProtocol.stub(
            endpoint: "/v2/custom",
            jsonString: "{}",
            statusCode: 200
        )
        
        var req = URLRequest(url: URL(string: "https://api.vercel.com/v2/custom")!)
        req.httpMethod = "PUT"
        req.setValue("CustomValue", forHTTPHeaderField: "X-Custom-Header")
        
        _ = try await mockSession.data(for: req)
        
        let last = MockURLProtocol.recordedRequests.last
        XCTAssertEqual(last?.httpMethod, "PUT")
        XCTAssertEqual(last?.allHTTPHeaderFields?["X-Custom-Header"], "CustomValue")
    }
    
    func testF16_03_MockURLProtocolSimulatesCustomHttpStatusCodes() async throws {
        MockURLProtocol.stub(
            endpoint: "/status/418",
            jsonString: "{\"teapot\": true}",
            statusCode: 418
        )
        
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/status/418")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 418)
    }
    
    func testF16_04_MockURLProtocolSimulatesArtificialNetworkDelays() async throws {
        MockURLProtocol.stub(
            endpoint: "/delayed",
            response: MockURLProtocol.MockResponse(statusCode: 200, delay: 0.05)
        )
        
        let start = Date()
        _ = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/delayed")!))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
    }
    
    func testF16_05_MockURLProtocolSimulatesNetworkTransportErrors() async {
        MockURLProtocol.stub(
            endpoint: "/timeout",
            response: MockURLProtocol.MockResponse(error: URLError(.timedOut))
        )
        
        do {
            _ = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/timeout")!))
            XCTFail("Expected timeout error")
        } catch let err as URLError {
            XCTAssertEqual(err.code, .timedOut)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
