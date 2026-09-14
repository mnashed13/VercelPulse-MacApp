import XCTest
@testable import VercelPulse

final class InMemoryKeychainManager: KeychainManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Data] = [:]
    
    func save(key: String, string: String) throws {
        guard let data = string.data(using: .utf8) else { return }
        try save(key: key, data: data)
    }
    
    func save(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        store[key] = data
    }
    
    func getString(key: String) -> String? {
        guard let data = try? getData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getData(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }
    
    func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
    
    func purgeAll() throws {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }
    
    func saveToken(_ token: OAuthToken) throws {
        let data = try JSONEncoder().encode(token)
        try save(key: KeychainKeys.oauthToken, data: data)
    }
    
    func getToken() -> OAuthToken? {
        if let data = try? getData(key: KeychainKeys.oauthToken) {
            return try? JSONDecoder().decode(OAuthToken.self, from: data)
        }
        if let legacy = getString(key: KeychainKeys.legacyToken) {
            return OAuthToken(accessToken: legacy)
        }
        return nil
    }
}

@MainActor
final class DashboardViewModelTests: XCTestCase {
    
    private var mockKeychain: InMemoryKeychainManager!
    private var mockSession: URLSession!
    private var apiService: VercelAPIService!
    private var oauthService: VercelOAuthService!
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        mockKeychain = InMemoryKeychainManager()
        mockSession = MockURLProtocol.makeMockSession()
        
        oauthService = VercelOAuthService(
            keychainManager: mockKeychain,
            session: mockSession
        )
        
        apiService = VercelAPIService(
            baseURL: "https://api.vercel.com",
            session: mockSession,
            keychain: mockKeychain,
            oauthService: oauthService
        )
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
        mockKeychain = nil
        mockSession = nil
        apiService = nil
        oauthService = nil
        super.tearDown()
    }
    
    // MARK: - Auth Status & Initialization
    
    func testInitialization_Unauthenticated() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentToken)
        XCTAssertTrue(viewModel.deployments.isEmpty)
    }
    
    func testInitialization_AuthenticatedFromKeychain() throws {
        let token = OAuthToken(
            accessToken: "test_token_123",
            refreshToken: "refresh_123",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: Date().addingTimeInterval(3600),
            scope: "user",
            teamId: "team_engineering",
            userId: "usr_alice"
        )
        try mockKeychain.saveToken(token)
        
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertEqual(viewModel.currentToken?.accessToken, "test_token_123")
        XCTAssertEqual(viewModel.currentToken?.teamId, "team_engineering")
    }
    
    // MARK: - Scope Filtering
    
    func testScopeFiltering_AllProductionAndPreview() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        let depProd = Deployment(
            uid: "dpl_prod",
            name: "prod-app",
            url: "prod-app.vercel.app",
            state: "READY",
            target: "production"
        )
        
        let depPrev = Deployment(
            uid: "dpl_prev",
            name: "prev-app",
            url: "prev-app.vercel.app",
            state: "READY",
            target: "preview"
        )
        
        let depBuilding = Deployment(
            uid: "dpl_bld",
            name: "bld-app",
            url: "bld-app.vercel.app",
            state: "BUILDING",
            target: "preview"
        )
        
        viewModel.deployments = [depProd, depPrev, depBuilding]
        viewModel.updateFilteredDeployments()
        
        // Scope All
        viewModel.selectedScope = FilterScope.all
        XCTAssertEqual(viewModel.filteredDeployments.count, 3)
        XCTAssertEqual(viewModel.allCount, 3)
        XCTAssertEqual(viewModel.productionCount, 1)
        XCTAssertEqual(viewModel.previewCount, 2)
        
        // Scope Production
        viewModel.selectedScope = FilterScope.production
        XCTAssertEqual(viewModel.filteredDeployments.count, 1)
        XCTAssertEqual(viewModel.filteredDeployments.first?.uid, "dpl_prod")
        
        // Scope Preview
        viewModel.selectedScope = FilterScope.preview
        XCTAssertEqual(viewModel.filteredDeployments.count, 2)
        XCTAssertEqual(viewModel.filteredDeployments.map { $0.uid }, ["dpl_prev", "dpl_bld"])
    }
    
    // MARK: - Adaptive Polling Engine
    
    func testAdaptivePolling_AcceleratesTo10sWhenBuildActive() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        let depBuilding = Deployment(
            uid: "dpl_bld",
            name: "bld-app",
            url: "bld-app.vercel.app",
            state: "BUILDING"
        )
        
        viewModel.deployments = [depBuilding]
        XCTAssertTrue(viewModel.hasActiveBuilds)
        
        let interval = viewModel.computePollingInterval()
        XCTAssertEqual(interval, 10.0)
    }
    
    func testAdaptivePolling_AcceleratesTo10sWhenQueued() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        let depQueued = Deployment(
            uid: "dpl_queued",
            name: "queued-app",
            url: "queued-app.vercel.app",
            state: "QUEUED"
        )
        
        viewModel.deployments = [depQueued]
        XCTAssertTrue(viewModel.hasActiveBuilds)
        
        let interval = viewModel.computePollingInterval()
        XCTAssertEqual(interval, 10.0)
    }
    
    func testAdaptivePolling_RelaxesTo60sWhenAllFinal() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        let depReady = Deployment(
            uid: "dpl_ready",
            name: "ready-app",
            url: "ready-app.vercel.app",
            state: "READY"
        )
        let depError = Deployment(
            uid: "dpl_err",
            name: "error-app",
            url: "error-app.vercel.app",
            state: "ERROR"
        )
        
        viewModel.deployments = [depReady, depError]
        XCTAssertFalse(viewModel.hasActiveBuilds)
        
        let interval = viewModel.computePollingInterval()
        XCTAssertEqual(interval, 60.0)
    }
    
    // MARK: - Clean Logout
    
    func testLogout_PurgesKeychainAndResetsState() throws {
        let token = OAuthToken(
            accessToken: "test_token_123",
            refreshToken: "refresh_123",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: Date().addingTimeInterval(3600),
            scope: "user",
            teamId: "team_engineering",
            userId: "usr_alice"
        )
        try mockKeychain.saveToken(token)
        
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        viewModel.deployments = [
            Deployment(uid: "1", name: "app", url: "app.vercel.app", state: "READY")
        ]
        viewModel.updateFilteredDeployments()
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertFalse(viewModel.deployments.isEmpty)
        
        viewModel.logout()
        
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.currentToken)
        XCTAssertTrue(viewModel.deployments.isEmpty)
        XCTAssertTrue(viewModel.filteredDeployments.isEmpty)
        XCTAssertNil(mockKeychain.getToken())
    }
    
    // MARK: - Save PAT Fallback
    
    func testSavePAT_PersistsTokenAndAuthenticates() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        viewModel.savePAT(token: "pat_sample_12345", teamId: "team_finance")
        
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertEqual(mockKeychain.getToken()?.accessToken, "pat_sample_12345")
        XCTAssertEqual(mockKeychain.getToken()?.teamId, "team_finance")
    }
    
    // MARK: - Error Banner Presentation
    
    func testErrorBannerType_Mapping() {
        let unauth = ErrorBannerType.from(apiError: .unauthorized)
        XCTAssertEqual(unauth, .unauthorized)
        
        let rateLimit = ErrorBannerType.from(apiError: .rateLimited(retryAfter: 30))
        XCTAssertEqual(rateLimit, .rateLimited(retryAfter: 30))
        
        let offline = ErrorBannerType.from(apiError: .networkError("The Internet connection appears to be offline."))
        XCTAssertEqual(offline, .networkOffline("The Internet connection appears to be offline."))
    }
    
    // MARK: - Dynamic Build Status & Menu Bar Icon Tests
    
    func testActiveBuildStatusAndColors() {
        let viewModel = DashboardViewModel(
            apiService: apiService,
            oauthService: oauthService,
            keychain: mockKeychain,
            autoStart: false
        )
        
        // Idle / No deployments
        XCTAssertFalse(viewModel.hasActiveBuilds)
        XCTAssertEqual(viewModel.menuBarSystemImage, "triangle.fill")
        
        // Queued deployment
        let queuedDep = Deployment(uid: "dep_q", name: "app", url: "app.com", state: "QUEUED")
        viewModel.deployments = [queuedDep]
        XCTAssertTrue(viewModel.hasActiveBuilds)
        XCTAssertEqual(viewModel.activeBuildStatusText, "Queued...")
        XCTAssertEqual(viewModel.menuBarSystemImage, "clock.arrow.circlepath")
        
        // Building deployment
        let buildingDep = Deployment(uid: "dep_b", name: "app", url: "app.com", state: "BUILDING")
        viewModel.deployments = [buildingDep, queuedDep]
        XCTAssertTrue(viewModel.hasActiveBuilds)
        XCTAssertEqual(viewModel.activeBuildStatusText, "Building...")
        XCTAssertEqual(viewModel.menuBarSystemImage, "arrow.triangle.2.circlepath")
        
        // Ready deployment
        let readyDep = Deployment(uid: "dep_r", name: "app", url: "app.com", state: "READY")
        viewModel.deployments = [readyDep]
        XCTAssertFalse(viewModel.hasActiveBuilds)
        XCTAssertEqual(viewModel.menuBarSystemImage, "triangle.fill")
        
        // Failed deployment
        let errorDep = Deployment(uid: "dep_e", name: "app", url: "app.com", state: "ERROR")
        viewModel.deployments = [errorDep]
        XCTAssertFalse(viewModel.hasActiveBuilds)
        XCTAssertEqual(viewModel.menuBarSystemImage, "exclamationmark.triangle.fill")
    }
}
