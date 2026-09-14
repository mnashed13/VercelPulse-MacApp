import XCTest
@testable import VercelPulse

final class APIServiceTests: XCTestCase {
    
    final class InMemoryKeychain: KeychainManaging, @unchecked Sendable {
        private var token: OAuthToken?
        private var strings: [String: String] = [:]
        private var data: [String: Data] = [:]
        
        init(token: OAuthToken? = nil) {
            self.token = token
        }
        
        func save(key: String, string: String) throws { strings[key] = string }
        func save(key: String, data: Data) throws { self.data[key] = data }
        func getString(key: String) -> String? { strings[key] }
        func getData(key: String) throws -> Data? { data[key] }
        func delete(key: String) throws {
            strings.removeValue(forKey: key)
            data.removeValue(forKey: key)
            if key == KeychainKeys.oauthToken { token = nil }
        }
        func purgeAll() throws {
            strings.removeAll()
            data.removeAll()
            token = nil
        }
        func saveToken(_ token: OAuthToken) throws { self.token = token }
        func getToken() -> OAuthToken? { token }
    }
    
    var session: URLSession!
    var mockKeychain: InMemoryKeychain!
    var apiService: VercelAPIService!
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        session = MockURLProtocol.makeMockSession()
        mockKeychain = InMemoryKeychain(
            token: OAuthToken(
                accessToken: "test_token_123",
                refreshToken: "refresh_token_abc",
                tokenType: "Bearer",
                expiresIn: 3600,
                expiresAt: Date().addingTimeInterval(3600),
                scope: "user",
                teamId: "team_alpha_prod_001",
                userId: "usr_123"
            )
        )
        apiService = VercelAPIService(
            baseURL: "https://api.vercel.com",
            session: session,
            keychain: mockKeychain
        )
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
        mockKeychain = nil
        session = nil
        apiService = nil
        super.tearDown()
    }
    
    // MARK: - Direct URLSession & Fixture Tests
    
    func testFetchDeploymentsSuccess() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments?limit=10&teamId=team_alpha_prod_001")!
        var request = URLRequest(url: url)
        request.setValue("Bearer test_token_123", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        
        let decoded = try JSONDecoder().decode(TestDeploymentsResponse.self, from: data)
        XCTAssertEqual(decoded.deployments.count, 6)
        XCTAssertEqual(decoded.deployments[0].uid, "dpl_build_001")
        XCTAssertEqual(decoded.deployments[0].typedState, .building)
        XCTAssertEqual(decoded.deployments[1].uid, "dpl_ready_002")
        XCTAssertEqual(decoded.deployments[1].typedState, .ready)
        XCTAssertEqual(decoded.pagination?.count, 6)
    }
    
    func testFetchProjectsSuccess() async throws {
        MockURLProtocol.stub(
            endpoint: "/v9/projects",
            jsonString: TestFixtures.projectsListJSON,
            statusCode: 200
        )
        
        let url = URL(string: "https://api.vercel.com/v9/projects")!
        var request = URLRequest(url: url)
        request.setValue("Bearer test_token_123", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        
        struct ProjectsResponse: Decodable {
            let projects: [TestProject]
        }
        let decoded = try JSONDecoder().decode(ProjectsResponse.self, from: data)
        XCTAssertEqual(decoded.projects.count, 3)
        XCTAssertEqual(decoded.projects[0].name, "nextjs-storefront")
        XCTAssertEqual(decoded.projects[0].framework, "nextjs")
    }
    
    func testFetchUsageSuccess() async throws {
        MockURLProtocol.stub(
            endpoint: "/v2/usage",
            jsonString: TestFixtures.usageMetricsJSON,
            statusCode: 200
        )
        
        let url = URL(string: "https://api.vercel.com/v2/usage")!
        var request = URLRequest(url: url)
        request.setValue("Bearer test_token_123", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        
        let decoded = try JSONDecoder().decode(TestUsage.self, from: data)
        XCTAssertNotNil(decoded.metrics?["bandwidth"])
        XCTAssertEqual(decoded.metrics?["bandwidth"]?.limit, 1073741824000)
        XCTAssertEqual(decoded.metrics?["bandwidth"]?.usage, 214748364800)
    }
    
    func testHandle401UnauthorizedError() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error401UnauthorizedJSON,
            statusCode: 401
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments")!
        var request = URLRequest(url: url)
        request.setValue("Bearer invalid_expired_token", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 401)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errorDict = json?["error"] as? [String: Any]
        XCTAssertEqual(errorDict?["code"] as? String, "unauthorized")
    }
    
    func testHandle429RateLimitWithRetryAfterHeader() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error429RateLimitedJSON,
            statusCode: 429,
            headers: ["Retry-After": "45"]
        )
        
        let url = URL(string: "https://api.vercel.com/v6/deployments")!
        let (data, response) = try await session.data(for: URLRequest(url: url))
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        
        XCTAssertEqual(httpResponse.statusCode, 429)
        XCTAssertEqual(httpResponse.value(forHTTPHeaderField: "Retry-After"), "45")
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errorDict = json?["error"] as? [String: Any]
        XCTAssertEqual(errorDict?["code"] as? String, "rate_limited")
    }
    
    // MARK: - VercelAPIService Class Integration Tests
    
    func testVercelAPIService_FetchDeployments_DecodingAndModels() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let response = try await apiService.fetchDeployments(
            teamId: "team_alpha_prod_001",
            projectId: nil,
            limit: 10,
            until: nil
        )
        
        XCTAssertEqual(response.deployments.count, 6)
        XCTAssertEqual(response.pagination?.count, 6)
        
        let first = response.deployments[0]
        XCTAssertEqual(first.uid, "dpl_build_001")
        XCTAssertEqual(first.name, "nextjs-storefront")
        XCTAssertEqual(first.status, .building)
        XCTAssertTrue(first.status.isInProgress)
        XCTAssertFalse(first.status.isLive)
        XCTAssertEqual(first.meta?.commitMessage, "feat(cart): implement one-click checkout modal")
        XCTAssertEqual(first.meta?.branchName, "feat/checkout-flow")
        XCTAssertEqual(first.meta?.shortSha, "a1b2c3d")
        XCTAssertEqual(first.creator?.username, "alexdeveloper")
        
        let second = response.deployments[1]
        XCTAssertEqual(second.status, .ready)
        XCTAssertTrue(second.status.isLive)
        XCTAssertTrue(second.isProduction)
    }
    
    func testVercelAPIService_FetchDeployments_ConvenienceHelper() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.deploymentsListJSON,
            statusCode: 200
        )
        
        let deployments = try await apiService.fetchDeployments()
        XCTAssertEqual(deployments.count, 6)
    }
    
    func testVercelAPIService_FetchProjects_Success() async throws {
        MockURLProtocol.stub(
            endpoint: "/v9/projects",
            jsonString: TestFixtures.projectsListJSON,
            statusCode: 200
        )
        
        let projects = try await apiService.fetchProjects(teamId: "team_alpha_prod_001")
        XCTAssertEqual(projects.count, 3)
        XCTAssertEqual(projects[0].name, "nextjs-storefront")
        XCTAssertEqual(projects[0].framework, "nextjs")
    }
    
    func testVercelAPIService_FetchUsage_Success() async throws {
        MockURLProtocol.stub(
            endpoint: "/v2/usage",
            jsonString: TestFixtures.usageMetricsJSON,
            statusCode: 200
        )
        
        let usage = try await apiService.fetchUsage(teamId: "team_alpha_prod_001")
        XCTAssertNotNil(usage.metrics?["bandwidth"])
        XCTAssertEqual(usage.metrics?["bandwidth"]?.limit, 1073741824000)
    }
    
    func testVercelAPIService_ThrowsMissingToken_WhenUnauthenticated() async {
        try? mockKeychain.purgeAll()
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown missingToken")
        } catch let error as VercelAPIService.APIError {
            XCTAssertEqual(error, .missingToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVercelAPIService_401Unauthorized_ReactiveRefreshAndRetrySuccess() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                return MockURLProtocol.MockResponse(
                    statusCode: 401,
                    data: TestFixtures.data(from: TestFixtures.error401UnauthorizedJSON)
                )
            } else {
                return MockURLProtocol.MockResponse(
                    statusCode: 200,
                    data: TestFixtures.data(from: TestFixtures.deploymentsListJSON)
                )
            }
        }
        
        var refreshCalled = false
        apiService.tokenRefresher = { [weak self] in
            refreshCalled = true
            let refreshed = OAuthToken(
                accessToken: "refreshed_token_456",
                refreshToken: "refresh_new",
                tokenType: "Bearer"
            )
            try? self?.mockKeychain.saveToken(refreshed)
            return refreshed
        }
        
        let deployments = try await apiService.fetchDeployments()
        XCTAssertTrue(refreshCalled)
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(deployments.count, 6)
    }
    
    func testVercelAPIService_401Unauthorized_RefreshFailureThrowsUnauthorized() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error401UnauthorizedJSON,
            statusCode: 401
        )
        
        apiService.tokenRefresher = {
            throw NSError(domain: "OAuth", code: 400, userInfo: nil)
        }
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown unauthorized")
        } catch let error as VercelAPIService.APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVercelAPIService_403Forbidden() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error403ForbiddenJSON,
            statusCode: 403
        )
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown forbidden")
        } catch let error as VercelAPIService.APIError {
            XCTAssertEqual(error, .forbidden)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVercelAPIService_429RateLimit_WithRetryAfter() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error429RateLimitedJSON,
            statusCode: 429,
            headers: ["Retry-After": "30"]
        )
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown rateLimited")
        } catch let error as VercelAPIService.APIError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 30))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVercelAPIService_500ServerError() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: TestFixtures.error500ServerErrorJSON,
            statusCode: 500
        )
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown serverError")
        } catch let error as VercelAPIService.APIError {
            if case .serverError(let code, _) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVercelAPIService_DecodingFailed_OnInvalidJSON() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            jsonString: "{ invalid json payload",
            statusCode: 200
        )
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown decodingFailed")
        } catch let error as VercelAPIService.APIError {
            if case .decodingFailed = error {
                // Expected
            } else {
                XCTFail("Expected decodingFailed, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testVercelAPIService_NetworkError_OnURLError() async {
        MockURLProtocol.stub(
            endpoint: "/v6/deployments",
            response: MockURLProtocol.MockResponse(error: URLError(.notConnectedToInternet))
        )
        
        do {
            _ = try await apiService.fetchDeployments()
            XCTFail("Should have thrown networkError")
        } catch let error as VercelAPIService.APIError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Build State UI Updates & Equatable Differentiation Tests
    
    func testDeployment_StateTransition_EvaluatesAsNotEqual() {
        let depBuilding = Deployment(
            uid: "dpl_active_001",
            name: "web-app",
            url: "web-app.vercel.app",
            state: "BUILDING"
        )
        let depReady = Deployment(
            uid: "dpl_active_001",
            name: "web-app",
            url: "web-app.vercel.app",
            state: "READY",
            ready: 1725184900000
        )
        let depError = Deployment(
            uid: "dpl_active_001",
            name: "web-app",
            url: "web-app.vercel.app",
            state: "ERROR"
        )
        
        // Critical for SwiftUI view invalidation inside ForEach:
        XCTAssertNotEqual(depBuilding, depReady, "Transition from BUILDING to READY must evaluate as not equal")
        XCTAssertNotEqual(depBuilding, depError, "Transition from BUILDING to ERROR must evaluate as not equal")
        XCTAssertNotEqual(depReady, depError, "Different terminal states must evaluate as not equal")
        XCTAssertEqual(depBuilding, depBuilding, "Identical deployment instances must evaluate as equal")
        
        // Identity strings must differ to force SwiftUI view updates
        XCTAssertNotEqual(depBuilding.idAndState, depReady.idAndState)
        XCTAssertNotEqual(depBuilding.idAndState, depError.idAndState)
    }
    
    func testDeploymentState_Aliases_ResolveCorrectly() {
        XCTAssertEqual(DeploymentState(apiState: "FAILED"), .error)
        XCTAssertEqual(DeploymentState(apiState: "FAILURE"), .error)
        XCTAssertEqual(DeploymentState(apiState: "CANCELLED"), .canceled)
        XCTAssertEqual(DeploymentState(apiState: "SUCCESS"), .ready)
        XCTAssertEqual(DeploymentState(apiState: "SUCCEEDED"), .ready)
        XCTAssertEqual(DeploymentState(apiState: "IN_PROGRESS"), .building)
        XCTAssertEqual(DeploymentState(apiState: "DEPLOYING"), .building)
        XCTAssertEqual(DeploymentState(apiState: "PENDING"), .queued)
    }
    
    func testDeployment_StatusFallbackAndResilience() throws {
        // Payload with readyState: "BUILDING"
        let jsonReadyState = """
        { "uid": "dpl_1", "name": "app", "url": "app.com", "readyState": "BUILDING", "created": 100 }
        """
        let dep1 = try JSONDecoder().decode(Deployment.self, from: jsonReadyState.data(using: .utf8)!)
        XCTAssertEqual(dep1.status, .building)
        
        // Payload with status: "READY"
        let jsonStatus = """
        { "uid": "dpl_2", "name": "app", "url": "app.com", "status": "READY", "created": 100 }
        """
        let dep2 = try JSONDecoder().decode(Deployment.self, from: jsonStatus.data(using: .utf8)!)
        XCTAssertEqual(dep2.status, .ready)
        
        // Payload with alias state: "FAILED"
        let jsonFailed = """
        { "uid": "dpl_3", "name": "app", "url": "app.com", "state": "FAILED", "created": 100 }
        """
        let dep3 = try JSONDecoder().decode(Deployment.self, from: jsonFailed.data(using: .utf8)!)
        XCTAssertEqual(dep3.status, .error)
    }
}
