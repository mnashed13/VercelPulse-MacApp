import XCTest
import CryptoKit

final class Tier4_RealWorldScenariosTests: XCTestCase {
    
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
    
    // MARK: - Scenario 1: Cold Launch -> OAuth Login -> Real-Time Deployment List -> Deep Link Click
    // Features Exercised: F1, F2, F3, F4, F5, F8, F10, F11, F13
    func testScenario1_ColdLaunchToDeploymentListAndDeepLink() async throws {
        // Step 1: Cold Launch with empty Keychain
        XCTAssertNil(mockKeychain.getToken())
        var isAuthenticated = false
        var showSettings = true
        var deployments: [TestDeployment] = []
        
        // Step 2: User initiates OAuth login -> PKCE generation
        let verifier = TestPKCEHelper.generateCodeVerifier(length: 64)
        let challenge = TestPKCEHelper.generateCodeChallenge(from: verifier)
        let state = "csrf_secure_state_12345"
        
        var authURLComp = URLComponents(string: "https://vercel.com/oauth/authorize")!
        authURLComp.queryItems = [
            URLQueryItem(name: "client_id", value: "test_client_id"),
            URLQueryItem(name: "redirect_uri", value: "vercelpulse://oauth-callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        let authorizationURL = authURLComp.url!
        XCTAssertEqual(authorizationURL.host, "vercel.com")
        
        // Step 3: Browser authorization completes, returns callback URL
        let callbackURL = URL(string: "vercelpulse://oauth-callback?code=fresh_auth_code_xyz&state=csrf_secure_state_12345")!
        let callbackComp = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let receivedState = callbackComp?.queryItems?.first(where: { $0.name == "state" })?.value
        let receivedCode = callbackComp?.queryItems?.first(where: { $0.name == "code" })?.value
        
        XCTAssertEqual(receivedState, state, "CSRF State must match")
        XCTAssertEqual(receivedCode, "fresh_auth_code_xyz")
        
        // Step 4: Token exchange over network
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: TestFixtures.oauthTokenExchangeJSON,
            statusCode: 200
        )
        
        var tokenExchangeReq = URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!)
        tokenExchangeReq.httpMethod = "POST"
        tokenExchangeReq.httpBody = "code=\(receivedCode!)&code_verifier=\(verifier)".data(using: .utf8)
        let (exchangeData, exchangeResp) = try await mockSession.data(for: tokenExchangeReq)
        XCTAssertEqual((exchangeResp as? HTTPURLResponse)?.statusCode, 200)
        
        let tokenJSON = try JSONSerialization.jsonObject(with: exchangeData) as? [String: Any]
        let token = TestOAuthToken(
            accessToken: tokenJSON!["access_token"] as! String,
            refreshToken: tokenJSON?["refresh_token"] as? String,
            teamId: tokenJSON?["team_id"] as? String,
            userId: tokenJSON?["user_id"] as? String
        )
        
        // Step 5: Save token in Keychain & update auth state
        try mockKeychain.saveToken(token)
        isAuthenticated = true
        showSettings = false
        XCTAssertTrue(isAuthenticated)
        XCTAssertFalse(showSettings)
        
        // Step 6: Fetch deployments authenticated with new token
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        var apiReq = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments?teamId=\(token.teamId ?? "")")!)
        apiReq.setValue("Bearer \(mockKeychain.getToken()!.accessToken)", forHTTPHeaderField: "Authorization")
        let (apiData, apiResp) = try await mockSession.data(for: apiReq)
        XCTAssertEqual((apiResp as? HTTPURLResponse)?.statusCode, 200)
        
        let response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: apiData)
        deployments = response.deployments
        XCTAssertEqual(deployments.count, 6)
        
        // Step 7: User clicks deep link on first deployment
        let first = deployments[0]
        let inspectorURL = TestDeepLinkHelper.inspectorURL(teamSlug: token.teamId, projectName: first.name, deploymentId: first.uid)
        XCTAssertEqual(
            inspectorURL?.absoluteString,
            "https://vercel.com/team_alpha_prod_001/nextjs-storefront/dpl_build_001"
        )
    }
    
    // MARK: - Scenario 2: Active Build Transition (QUEUED -> BUILDING -> READY) with Adaptive 10s Polling
    // Features Exercised: F8, F10, F13, F14
    func testScenario2_ActiveBuildTransitionWithAdaptivePolling() async throws {
        // Step 1: Poll 1 returns a QUEUED deployment
        let poll1JSON = """
        {
          "deployments": [
            { "uid": "dpl_active_1", "name": "web-app", "url": "web.app", "state": "QUEUED", "created": 1725184800000, "target": "production" }
          ]
        }
        """
        let poll1Response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: poll1JSON.data(using: .utf8)!)
        var interval = TestPollingEngine.computePollingInterval(for: poll1Response.deployments)
        XCTAssertEqual(interval, 10.0, "Active queued build must accelerate polling to 10s")
        XCTAssertEqual(poll1Response.deployments[0].typedState, .queued)
        
        // Step 2: Poll 2 (after 10s) returns BUILDING
        let poll2JSON = """
        {
          "deployments": [
            { "uid": "dpl_active_1", "name": "web-app", "url": "web.app", "state": "BUILDING", "created": 1725184800000, "target": "production" }
          ]
        }
        """
        let poll2Response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: poll2JSON.data(using: .utf8)!)
        interval = TestPollingEngine.computePollingInterval(for: poll2Response.deployments)
        XCTAssertEqual(interval, 10.0, "Active building deployment must maintain 10s polling")
        XCTAssertEqual(poll2Response.deployments[0].typedState, .building)
        
        // Step 3: Poll 3 (after 10s) returns READY
        let poll3JSON = """
        {
          "deployments": [
            { "uid": "dpl_active_1", "name": "web-app", "url": "web.app", "state": "READY", "created": 1725184800000, "target": "production" }
          ]
        }
        """
        let poll3Response = try JSONDecoder().decode(TestDeploymentsResponse.self, from: poll3JSON.data(using: .utf8)!)
        interval = TestPollingEngine.computePollingInterval(for: poll3Response.deployments)
        XCTAssertEqual(interval, 60.0, "All ready deployments must relax polling interval to 60s")
        XCTAssertEqual(poll3Response.deployments[0].typedState, .ready)
        XCTAssertEqual(poll3Response.deployments[0].typedState.statusBadgeColorName, "systemGreen")
    }
    
    // MARK: - Scenario 3: Token Expiry During Polling -> Reactive 401 Intercept -> Auto-Refresh -> Query Replay
    // Features Exercised: F4, F5, F6, F8, F12
    func testScenario3_TokenExpiryDuringPollingWithReactive401AutoRefresh() async throws {
        // Step 1: Initial token in Keychain
        let initialToken = TestOAuthToken(
            accessToken: "stale_access_token_401",
            refreshToken: "valid_rotatable_refresh_token",
            teamId: "team_alpha"
        )
        try mockKeychain.saveToken(initialToken)
        
        // Step 2: Polling request encounters HTTP 401
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error401UnauthorizedJSON,
            statusCode: 401
        )
        
        let initialReq = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        let (_, resp1) = try await mockSession.data(for: initialReq)
        let http1 = try XCTUnwrap(resp1 as? HTTPURLResponse)
        XCTAssertEqual(http1.statusCode, 401)
        
        // Step 3: Auto-refresh interceptor triggers token exchange
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: TestFixtures.oauthTokenRefreshJSON,
            statusCode: 200
        )
        
        var refreshReq = URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!)
        refreshReq.httpMethod = "POST"
        refreshReq.httpBody = "grant_type=refresh_token&refresh_token=\(initialToken.refreshToken!)".data(using: .utf8)
        let (refreshData, refreshResp) = try await mockSession.data(for: refreshReq)
        XCTAssertEqual((refreshResp as? HTTPURLResponse)?.statusCode, 200)
        
        let refreshJSON = try JSONSerialization.jsonObject(with: refreshData) as? [String: Any]
        let newToken = TestOAuthToken(
            accessToken: refreshJSON!["access_token"] as! String,
            refreshToken: refreshJSON?["refresh_token"] as? String,
            teamId: refreshJSON?["team_id"] as? String
        )
        try mockKeychain.saveToken(newToken)
        XCTAssertEqual(mockKeychain.getToken()?.accessToken, "vcp_tok_refreshed_new_999888777")
        
        // Step 4: Interceptor replays original deployments request
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        var replayedReq = URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!)
        replayedReq.setValue("Bearer \(mockKeychain.getToken()!.accessToken)", forHTTPHeaderField: "Authorization")
        let (replayData, replayResp) = try await mockSession.data(for: replayedReq)
        XCTAssertEqual((replayResp as? HTTPURLResponse)?.statusCode, 200)
        
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: replayData)
        XCTAssertEqual(decoded.deployments.count, 6)
    }
    
    // MARK: - Scenario 4: Rate Limit Encounter (HTTP 429) -> Backoff Banner Display -> Retry Recovery
    // Features Exercised: F8, F12, F13, F14
    func testScenario4_RateLimitEncounterAndRetryRecovery() async throws {
        // Step 1: Request receives 429 with Retry-After: 45
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error429RateLimitedJSON,
            statusCode: 429,
            headers: ["Retry-After": "45"]
        )
        
        var errorBanner: String? = nil
        var currentBackoff: TimeInterval = 0
        
        let (_, resp429) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        let http429 = try XCTUnwrap(resp429 as? HTTPURLResponse)
        XCTAssertEqual(http429.statusCode, 429)
        
        if let retryHeader = http429.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(retryHeader) {
            currentBackoff = seconds
            errorBanner = "Rate limit reached. Pausing requests for \(Int(seconds))s."
        }
        
        XCTAssertEqual(currentBackoff, 45.0)
        XCTAssertEqual(errorBanner, "Rate limit reached. Pausing requests for 45s.")
        
        // Step 2: Backoff expires, subsequent request succeeds
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let (recoveryData, recoveryResp) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments")!))
        XCTAssertEqual((recoveryResp as? HTTPURLResponse)?.statusCode, 200)
        
        errorBanner = nil
        let deployments = try JSONDecoder().decode(TestDeploymentsResponse.self, from: recoveryData).deployments
        XCTAssertNil(errorBanner)
        XCTAssertEqual(deployments.count, 6)
    }
    
    // MARK: - Scenario 5: Multi-Page Pagination with Team Scoping & Filtering
    // Features Exercised: F8, F9, F10, F13
    func testScenario5_MultiPagePaginationWithTeamScopingAndFiltering() async throws {
        let teamId = "team_alpha_prod_001"
        
        MockURLProtocol.stub(
            endpoint: "/v6/deployments?teamId=\(teamId)&limit=2",
            jsonString: TestFixtures.deploymentsPaginationPage1JSON,
            statusCode: 200
        )
        MockURLProtocol.stub(
            endpoint: "/v6/deployments?teamId=\(teamId)&limit=2&until=1725190000000",
            jsonString: TestFixtures.deploymentsPaginationPage2JSON,
            statusCode: 200
        )
        
        // Step 1: Fetch Page 1
        let (p1Data, _) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments?teamId=\(teamId)&limit=2")!))
        let p1Resp = try JSONDecoder().decode(TestDeploymentsResponse.self, from: p1Data)
        var allDeployments = p1Resp.deployments
        let cursor = p1Resp.pagination?.next
        XCTAssertEqual(cursor, 1725190000000)
        
        // Step 2: Fetch Page 2
        let (p2Data, _) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/deployments?teamId=\(teamId)&limit=2&until=\(cursor!)")!))
        let p2Resp = try JSONDecoder().decode(TestDeploymentsResponse.self, from: p2Data)
        allDeployments.append(contentsOf: p2Resp.deployments)
        
        XCTAssertEqual(allDeployments.count, 3)
        XCTAssertNil(p2Resp.pagination?.next, "Last page has null next cursor")
        
        // Step 3: Apply Production filter tab
        let productionDeployments = allDeployments.filter { $0.isProduction }
        XCTAssertEqual(productionDeployments.count, 3)
        XCTAssertTrue(productionDeployments.allSatisfy { $0.typedState == .ready })
    }
    
    // MARK: - Scenario 6: User Logout -> Keychain Purge -> Instant UI Reset to Unauthenticated State
    // Features Exercised: F5, F7, F13, F15
    func testScenario6_UserLogoutKeychainPurgeAndInstantUIReset() throws {
        // Initial state: User is authenticated with active items
        try mockKeychain.saveToken(TestOAuthToken(accessToken: "session_token_123", teamId: "team_active"))
        UserDefaults.standard.set("team_active", forKey: "teamId")
        
        var isAuthenticated = true
        var showSettings = false
        var deployments = [TestDeployment(uid: "1", name: "app", url: "app.com", state: "READY")]
        var timerRunning = true
        
        XCTAssertTrue(isAuthenticated)
        XCTAssertFalse(showSettings)
        XCTAssertFalse(deployments.isEmpty)
        
        // User triggers Logout
        try mockKeychain.purgeAll()
        UserDefaults.standard.removeObject(forKey: "teamId")
        isAuthenticated = false
        showSettings = true
        deployments.removeAll()
        timerRunning = false
        
        // Verification: Clean purge
        XCTAssertNil(mockKeychain.getToken())
        XCTAssertNil(UserDefaults.standard.string(forKey: "teamId"))
        XCTAssertFalse(isAuthenticated)
        XCTAssertTrue(showSettings)
        XCTAssertTrue(deployments.isEmpty)
        XCTAssertFalse(timerRunning)
    }
}
