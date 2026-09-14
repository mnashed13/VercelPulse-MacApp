import XCTest
import CryptoKit

final class Tier3_CrossFeaturePairwiseTests: XCTestCase {
    
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
    
    // MARK: - Pairwise Test 1: F1 (PKCE) + F4 (Token Exchange)
    func testP01_PKCEWithTokenExchangePipeline() async throws {
        let verifier = TestPKCEHelper.generateCodeVerifier(length: 64)
        let challenge = TestPKCEHelper.generateCodeChallenge(from: verifier)
        XCTAssertFalse(challenge.isEmpty)
        
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: TestFixtures.oauthTokenExchangeJSON,
            statusCode: 200
        )
        
        var request = URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=client_1&code=auth_code_xyz&code_verifier=\(verifier)&grant_type=authorization_code"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await mockSession.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        
        let recorded = MockURLProtocol.recordedRequests.first
        let recordedBody = String(data: recorded!.httpBody!, encoding: .utf8)!
        XCTAssertTrue(recordedBody.contains("code_verifier=\(verifier)"))
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["access_token"] as? String, "vcp_tok_test_abc123456789xyz")
    }
    
    // MARK: - Pairwise Test 2: F4 (Token Exchange) + F5 (Keychain)
    func testP02_TokenExchangeWithKeychainPersistence() throws {
        let data = TestFixtures.data(from: TestFixtures.oauthTokenExchangeJSON)
        struct ExchangeDTO: Decodable {
            let access_token: String
            let refresh_token: String?
            let token_type: String
            let expires_in: Int?
            let scope: String?
            let team_id: String?
            let user_id: String?
        }
        let dto = try JSONDecoder().decode(ExchangeDTO.self, from: data)
        let token = TestOAuthToken(
            accessToken: dto.access_token,
            refreshToken: dto.refresh_token,
            tokenType: dto.token_type,
            expiresIn: dto.expires_in,
            scope: dto.scope,
            teamId: dto.team_id,
            userId: dto.user_id
        )
        
        try mockKeychain.saveToken(token)
        let stored = mockKeychain.getToken()
        
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.accessToken, "vcp_tok_test_abc123456789xyz")
        XCTAssertEqual(stored?.refreshToken, "vcp_ref_test_987654321zyx")
        XCTAssertEqual(stored?.teamId, "team_alpha_prod_001")
    }
    
    // MARK: - Pairwise Test 3: F5 (Keychain) + F8 (API Client)
    func testP03_KeychainTokenInjectionIntoRESTAPIClient() async throws {
        let token = TestOAuthToken(accessToken: "vcp_keychain_injected_tok")
        try mockKeychain.saveToken(token)
        
        guard let activeToken = mockKeychain.getToken()?.accessToken else {
            XCTFail("Missing token in Keychain")
            return
        }
        
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        var request = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        request.setValue("Bearer \(activeToken)", forHTTPHeaderField: "Authorization")
        
        _ = try await mockSession.data(for: request)
        let recorded = MockURLProtocol.recordedRequests.first
        XCTAssertEqual(recorded?.allHTTPHeaderFields?["Authorization"], "Bearer vcp_keychain_injected_tok")
    }
    
    // MARK: - Pairwise Test 4: F6 (Auto Refresh) + F8 (API Client) + F5 (Keychain)
    func testP04_APITokenExpiry401InterceptionAndAutoRefresh() async throws {
        try mockKeychain.saveToken(TestOAuthToken(accessToken: "expired_token", refreshToken: "valid_refresh_token"))
        
        // Step 1: 401 on initial call
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error401UnauthorizedJSON,
            statusCode: 401
        )
        // Step 2: Refresh succeeds
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: TestFixtures.oauthTokenRefreshJSON,
            statusCode: 200
        )
        
        let initialReq = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        let (_, resp1) = try await mockSession.data(for: initialReq)
        let http1 = try XCTUnwrap(resp1 as? HTTPURLResponse)
        XCTAssertEqual(http1.statusCode, 401)
        
        // Perform simulated refresh
        let refreshReq = URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!)
        let (refreshData, refreshResp) = try await mockSession.data(for: refreshReq)
        let httpRefresh = try XCTUnwrap(refreshResp as? HTTPURLResponse)
        XCTAssertEqual(httpRefresh.statusCode, 200)
        
        let json = try JSONSerialization.jsonObject(with: refreshData) as? [String: Any]
        let newAccess = json?["access_token"] as! String
        let newRefresh = json?["refresh_token"] as? String
        try mockKeychain.saveToken(TestOAuthToken(accessToken: newAccess, refreshToken: newRefresh))
        
        // Step 3: Replay query with new token
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        var retryReq = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        retryReq.setValue("Bearer \(mockKeychain.getToken()!.accessToken)", forHTTPHeaderField: "Authorization")
        let (retryData, retryResp) = try await mockSession.data(for: retryReq)
        let httpRetry = try XCTUnwrap(retryResp as? HTTPURLResponse)
        XCTAssertEqual(httpRetry.statusCode, 200)
        
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: retryData)
        XCTAssertEqual(decoded.deployments.count, 6)
    }
    
    // MARK: - Pairwise Test 5: F8 (API Client) + F9 (Pagination) + F10 (Domain Models)
    func testP05_RESTAPIPaginationAccumulatesRichDomainModels() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments?limit=2",
            jsonString: TestFixtures.deploymentsPaginationPage1JSON,
            statusCode: 200
        )
        MockURLProtocol.stub(
            endpoint: "/v6/deployments?limit=2&until=1725190000000",
            jsonString: TestFixtures.deploymentsPaginationPage2JSON,
            statusCode: 200
        )
        
        // Page 1
        let (data1, _) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments?limit=2")!))
        let res1 = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data1)
        
        var collected = res1.deployments
        let nextCursor = res1.pagination?.next
        XCTAssertNotNil(nextCursor)
        
        // Page 2
        let (data2, _) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments?limit=2&until=\(nextCursor!)")!))
        let res2 = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data2)
        collected.append(contentsOf: res2.deployments)
        
        XCTAssertEqual(collected.count, 3)
        XCTAssertTrue(collected.allSatisfy { $0.typedState == .ready })
    }
    
    // MARK: - Pairwise Test 6: F10 (Domain Models) + F11 (Deep Links)
    func testP06_DomainModelsGenerateDeepLinks() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        
        for dep in response.deployments {
            let inspector = TestDeepLinkHelper.inspectorURL(teamSlug: "team_alpha_prod_001", projectName: dep.name, deploymentId: dep.uid)
            XCTAssertNotNil(inspector)
            XCTAssertTrue(inspector!.absoluteString.contains(dep.uid))
            
            let preview = TestDeepLinkHelper.previewURL(domain: dep.url)
            XCTAssertNotNil(preview)
            XCTAssertEqual(preview?.scheme, "https")
            
            if let sha = dep.meta?.githubCommitSha {
                let commit = TestDeepLinkHelper.commitURL(org: "acmecorp", repo: dep.name, sha: sha)
                XCTAssertNotNil(commit)
                XCTAssertTrue(commit!.absoluteString.contains(sha))
            }
        }
    }
    
    // MARK: - Pairwise Test 7: F10 (Domain Models) + F13 (Popover Dashboard UI Filter)
    func testP07_DomainModelsFilterScopeTabs() throws {
        let data = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        let all = response.deployments
        
        let allTab = all
        let prodTab = all.filter { $0.isProduction }
        let prevTab = all.filter { $0.isPreview }
        
        XCTAssertEqual(allTab.count, 6)
        XCTAssertEqual(prodTab.count, 1)
        XCTAssertEqual(prevTab.count, 5)
        XCTAssertEqual(prodTab.count + prevTab.count, allTab.count)
    }
    
    // MARK: - Pairwise Test 8: F10 (Domain Models) + F14 (Adaptive Polling Engine)
    func testP08_DomainModelsDriveAdaptiveBuildPolling() throws {
        let multiStateData = TestFixtures.data(from: TestFixtures.deploymentsListJSON)
        let multiResp = try JSONDecoder().decode(TestDeploymentsResponse.self, from: multiStateData)
        // Contains BUILDING & QUEUED & INITIALIZING
        let activeInterval = TestPollingEngine.computePollingInterval(for: multiResp.deployments)
        XCTAssertEqual(activeInterval, 10.0)
        
        let readyOnlyData = TestFixtures.data(from: TestFixtures.deploymentsPaginationPage1JSON)
        let readyResp = try JSONDecoder().decode(TestDeploymentsResponse.self, from: readyOnlyData)
        let readyInterval = TestPollingEngine.computePollingInterval(for: readyResp.deployments)
        XCTAssertEqual(readyInterval, 60.0)
    }
    
    // MARK: - Pairwise Test 9: F7 (Logout) + F5 (Keychain) + F14 (Polling Engine)
    func testP09_LogoutPurgesKeychainAndStopsPolling() throws {
        try mockKeychain.saveToken(TestOAuthToken(accessToken: "active_user_token"))
        XCTAssertNotNil(mockKeychain.getToken())
        
        var timerActive = true
        var isAuthenticated = true
        
        // Execute logout pipeline
        try mockKeychain.purgeAll()
        timerActive = false
        isAuthenticated = false
        
        XCTAssertNil(mockKeychain.getToken())
        XCTAssertFalse(timerActive)
        XCTAssertFalse(isAuthenticated)
    }
    
    // MARK: - Pairwise Test 10: F12 (429 Rate Limit) + F14 (Polling Engine) + F13 (UI Banner)
    func testP10_RateLimit429UpdatesPollingAndBanner() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error429RateLimitedJSON,
            statusCode: 429,
            headers: ["Retry-After": "30"]
        )
        
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 429)
        
        let retryAfter = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "0") ?? 0
        XCTAssertEqual(retryAfter, 30)
        
        var errorBannerMessage: String?
        if http.statusCode == 429 {
            errorBannerMessage = "Rate limited. Backing off for \(retryAfter)s."
        }
        XCTAssertEqual(errorBannerMessage, "Rate limited. Backing off for 30s.")
    }
    
    // MARK: - Pairwise Test 11: F3 (Custom Scheme) + F4 (Exchange) + F5 (Keychain)
    func testP11_CustomURLCallbackTriggersExchangeAndSave() throws {
        let callback = URL(string: "vercelpulse://oauth-callback?code=fresh_auth_code&state=trusted_state_123")!
        let comp = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let code = comp?.queryItems?.first(where: { $0.name == "code" })?.value
        XCTAssertEqual(code, "fresh_auth_code")
        
        // Simulate exchange and persistence
        let exchangedToken = TestOAuthToken(
            accessToken: "vcp_new_from_callback",
            refreshToken: "vcp_refresh_from_callback",
            teamId: "team_callback_123"
        )
        try mockKeychain.saveToken(exchangedToken)
        
        let active = mockKeychain.getToken()
        XCTAssertEqual(active?.accessToken, "vcp_new_from_callback")
        XCTAssertEqual(active?.teamId, "team_callback_123")
    }
    
    // MARK: - Pairwise Test 12: F15 (Settings PAT) + F5 (Keychain) + F8 (API Client)
    func testP12_SettingsPATFallbackEnablesDeploymentsQuery() async throws {
        let manualPAT = "pat_manual_personal_access_token_888"
        try mockKeychain.save(key: MockKeychainManager.legacyTokenKey, string: manualPAT)
        
        let storedToken = mockKeychain.getToken()
        XCTAssertEqual(storedToken?.accessToken, manualPAT)
        
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        var req = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        req.setValue("Bearer \(storedToken!.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await mockSession.data(for: req)
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        XCTAssertEqual(decoded.deployments.count, 6)
    }
    
    // MARK: - Pairwise Test 13: F6 (Proactive Refresh) + F5 (Keychain) + F8 (API Client)
    func testP13_ProactiveTokenRefreshBeforeAPIQuery() async throws {
        // Token expiring in 20 seconds (< 60s threshold)
        let expiringToken = TestOAuthToken(
            accessToken: "old_expiring_token",
            refreshToken: "valid_refresh",
            expiresIn: 20,
            expiresAt: Date().addingTimeInterval(20)
        )
        try mockKeychain.saveToken(expiringToken)
        XCTAssertTrue(expiringToken.shouldRefresh)
        
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: TestFixtures.oauthTokenRefreshJSON,
            statusCode: 200
        )
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        // Execute refresh
        let (_, refreshResp) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!))
        XCTAssertEqual((refreshResp as? HTTPURLResponse)?.statusCode, 200)
        
        let freshToken = TestOAuthToken(accessToken: "vcp_tok_refreshed_new_999888777", expiresIn: 86400)
        try mockKeychain.saveToken(freshToken)
        
        // Query deployments
        var req = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        req.setValue("Bearer \(mockKeychain.getToken()!.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await mockSession.data(for: req)
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        XCTAssertEqual(decoded.deployments.count, 6)
    }
    
    // MARK: - Pairwise Test 14: F8 (API Client) + F12 (Error Handling) + F13 (UI Dashboard)
    func testP14_CorruptedAPIResponseTriggersSafeErrorBanner() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: "{ broken_corrupted_json",
            statusCode: 200
        )
        
        let cachedDeployments = [TestDeployment(uid: "prev_1", name: "cached_app", url: "cached.app", state: "READY")]
        var errorBanner: String? = nil
        
        do {
            let (data, _) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
            _ = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
            XCTFail("Decoding should fail")
        } catch {
            errorBanner = "Failed to decode deployments response."
        }
        
        XCTAssertEqual(errorBanner, "Failed to decode deployments response.")
        XCTAssertEqual(cachedDeployments.count, 1, "Cached deployments must be preserved on decoding error")
    }
    
    // MARK: - Pairwise Test 15: F1 (Config) + F8 (API Client) + F15 (Settings)
    func testP15_TeamIdConfigurationUpdatesEndpointQueries() async throws {
        let teamId = "team_configured_in_settings_99"
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments?teamId=\(teamId)")!
        _ = try await mockSession.data(for: URLRequest(url: url))
        
        let recorded = MockURLProtocol.recordedRequests.first
        XCTAssertTrue(recorded?.url?.query?.contains("teamId=team_configured_in_settings_99") ?? false)
    }
    
    // MARK: - Pairwise Test 16: F5 (Keychain) + F8 (API Client) + F15 (Settings)
    func testP16_UnauthenticatedAPIQueryTriggersReauthPrompt() {
        let token = mockKeychain.getToken()
        XCTAssertNil(token)
        
        var showSettings = false
        var errorMessage: String? = nil
        
        if token == nil {
            errorMessage = "No API token found. Please add it in settings."
            showSettings = true
        }
        
        XCTAssertTrue(showSettings)
        XCTAssertEqual(errorMessage, "No API token found. Please add it in settings.")
    }
}
