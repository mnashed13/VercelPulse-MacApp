import Foundation
import Combine
import SwiftUI

/// Main observable view model orchestrating authentication, deployment fetching, scope filtering,
/// error management, and the adaptive build-polling engine.
@MainActor
public final class DashboardViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published public var deployments: [Deployment] = []
    @Published public var filteredDeployments: [Deployment] = []
    @Published public var projects: [Project] = []
    @Published public var usage: Usage? = nil
    
    @Published public var selectedScope: FilterScope = .all {
        didSet {
            updateFilteredDeployments()
        }
    }
    
    @Published public var isLoading: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var activeAPIError: VercelAPIService.APIError? = nil
    
    @Published public var isAuthenticated: Bool = false
    @Published public var showSettings: Bool = false
    
    @Published public var currentPollingInterval: TimeInterval = 60.0
    @Published public var lastUpdated: Date? = nil
    @Published public var rateLimitResetDate: Date? = nil
    @Published public var currentToken: OAuthToken? = nil
    
    // MARK: - Configuration Properties
    
    public var basePollingInterval: TimeInterval = 60.0
    public var activePollingInterval: TimeInterval = 10.0
    
    // MARK: - Dependencies
    
    public let apiService: VercelAPIServicing
    public let oauthService: VercelOAuthServicing
    public let keychain: KeychainManaging
    
    // MARK: - Internal Timers & Tasks
    
    private var pollingTimer: AnyCancellable?
    private var activeFetchTask: Task<Void, Never>?
    
    // MARK: - Initializer
    
    public init(
        apiService: VercelAPIServicing? = nil,
        oauthService: VercelOAuthServicing? = nil,
        keychain: KeychainManaging? = nil,
        autoStart: Bool = true
    ) {
        self.apiService = apiService ?? VercelAPIService.shared
        self.oauthService = oauthService ?? VercelOAuthService.shared
        self.keychain = keychain ?? KeychainManager.shared
        
        checkAuthStatus()
        
        if autoStart {
            if isAuthenticated {
                startPolling()
                Task {
                    await fetchAllData()
                }
            } else {
                showSettings = false
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Indicates whether any deployment in the workspace is currently active (building, queued, or initializing).
    public var hasActiveBuilds: Bool {
        deployments.contains { $0.status.isInProgress }
    }
    
    /// User-facing status text for active workspace builds.
    public var activeBuildStatusText: String {
        if deployments.contains(where: { $0.status == .building }) {
            return "Building..."
        }
        if deployments.contains(where: { $0.status == .queued }) {
            return "Queued..."
        }
        if deployments.contains(where: { $0.status == .initializing }) {
            return "Initializing..."
        }
        return "Building..."
    }
    
    /// Theme color representing active workspace builds.
    public var activeBuildColor: Color {
        if deployments.contains(where: { $0.status == .building }) {
            return Color(red: 59/255, green: 130/255, blue: 246/255)
        }
        if deployments.contains(where: { $0.status == .queued || $0.status == .initializing }) {
            return Color(red: 245/255, green: 158/255, blue: 11/255)
        }
        return Color.blue
    }
    
    /// Most recent deployment in the workspace.
    public var latestDeployment: Deployment? {
        deployments.first
    }
    
    /// Typed status of the most recent deployment.
    public var latestDeploymentStatus: DeploymentState? {
        deployments.first?.status
    }
    
    /// User-facing status text reflecting current build state or workspace health.
    public var pulseStatusText: String {
        if hasActiveBuilds {
            return activeBuildStatusText
        }
        if let latest = deployments.first {
            switch latest.status {
            case .ready:
                return "Live"
            case .error:
                return "Build Failed"
            case .canceled:
                return "Canceled"
            case .building:
                return "Building..."
            case .queued:
                return "Queued..."
            case .initializing:
                return "Initializing..."
            case .unknown:
                return "Ready"
            }
        }
        return "Live"
    }
    
    /// Theme color representing the current pulse status.
    public var pulseStatusColor: Color {
        if hasActiveBuilds {
            return activeBuildColor
        }
        if let latest = deployments.first {
            switch latest.status {
            case .ready:
                return Color(red: 16/255, green: 185/255, blue: 129/255)
            case .error:
                return Color(red: 239/255, green: 68/255, blue: 68/255)
            case .canceled:
                return Color(red: 107/255, green: 114/255, blue: 128/255)
            case .building:
                return Color(red: 59/255, green: 130/255, blue: 246/255)
            case .queued, .initializing:
                return Color(red: 245/255, green: 158/255, blue: 11/255)
            case .unknown:
                return Color.gray
            }
        }
        return Color.green
    }
    
    /// Dynamic SF Symbol for MenuBarExtra based on current deployment states.
    public var menuBarSystemImage: String {
        if deployments.contains(where: { $0.status == .building }) {
            return "arrow.triangle.2.circlepath"
        }
        if deployments.contains(where: { $0.status == .queued || $0.status == .initializing }) {
            return "clock.arrow.circlepath"
        }
        if deployments.first?.status == .error {
            return "exclamationmark.triangle.fill"
        }
        return "triangle.fill"
    }
    
    public var allCount: Int {
        deployments.count
    }
    
    public var productionCount: Int {
        deployments.filter { $0.isProduction }.count
    }
    
    public var previewCount: Int {
        deployments.filter { $0.isPreview }.count
    }
    
    public var effectiveTeamSlug: String? {
        if let savedTeam = UserDefaults.standard.string(forKey: "teamId"), !savedTeam.isEmpty {
            return savedTeam
        }
        return currentToken?.teamId
    }
    
    public var currentUsername: String? {
        currentToken?.userId
    }
    
    // MARK: - Authentication Management
    
    public func checkAuthStatus() {
        currentToken = keychain.getToken()
        let hasValidToken = currentToken?.accessToken.isEmpty == false || oauthService.isAuthenticated
        isAuthenticated = hasValidToken
    }
    
    /// Launches the browser-based Vercel OAuth 2.0 flow.
    public func startOAuthLogin() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        activeAPIError = nil
        
        Task {
            do {
                let token = try await oauthService.startOAuthFlow()
                self.currentToken = token
                self.isAuthenticated = true
                self.isAuthenticating = false
                self.startPolling()
                await self.fetchAllData()
            } catch let error as OAuthError {
                self.isAuthenticating = false
                if error != .userCancelled {
                    self.errorMessage = error.localizedDescription
                }
            } catch {
                self.isAuthenticating = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Saves a manual Personal Access Token (PAT) fallback.
    public func savePAT(token: String, teamId: String? = nil) {
        errorMessage = nil
        activeAPIError = nil
        
        do {
            try oauthService.savePersonalAccessToken(token, teamId: teamId)
            checkAuthStatus()
            if isAuthenticated {
                startPolling()
                Task {
                    await fetchAllData()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Purges all session credentials from Keychain, resets view state, and stops background polling.
    public func logout() {
        stopPolling()
        activeFetchTask?.cancel()
        activeFetchTask = nil
        
        do {
            try oauthService.logout()
        } catch {
            try? keychain.purgeAll()
            UserDefaults.standard.removeObject(forKey: "teamId")
        }
        
        isAuthenticated = false
        currentToken = nil
        deployments = []
        filteredDeployments = []
        projects = []
        usage = nil
        errorMessage = nil
        activeAPIError = nil
        lastUpdated = nil
        rateLimitResetDate = nil
    }
    
    // MARK: - Data Fetching & Sync
    
    /// Refreshes all deployment and project data from the Vercel REST API.
    public func fetchAllData(isManual: Bool = false) async {
        // Prevent overlapping redundant fetches
        if isLoading && !isManual { return }
        
        // If rate limit is active, wait until reset
        if let reset = rateLimitResetDate, reset > Date() {
            let remaining = Int(reset.timeIntervalSinceNow)
            activeAPIError = .rateLimited(retryAfter: max(1, remaining))
            errorMessage = "Rate limit active. Retrying in \(max(1, remaining))s."
            return
        }
        
        isLoading = true
        if isManual {
            errorMessage = nil
            activeAPIError = nil
        }
        
        let targetTeamId = effectiveTeamSlug
        
        do {
            async let deploymentsTask = apiService.fetchDeployments(teamId: targetTeamId, projectId: nil, limit: 20, until: nil)
            async let projectsTask = apiService.fetchProjects(teamId: targetTeamId)
            
            let depResponse = try await deploymentsTask
            let fetchedProjects = (try? await projectsTask) ?? []
            
            self.deployments = depResponse.deployments
            self.projects = fetchedProjects
            self.updateFilteredDeployments()
            self.lastUpdated = Date()
            self.errorMessage = nil
            self.activeAPIError = nil
            self.rateLimitResetDate = nil
            
            // Try fetching usage independently (non-fatal)
            do {
                self.usage = try await apiService.fetchUsage(teamId: targetTeamId)
            } catch {
                self.usage = nil
            }
            
            // Re-evaluate adaptive polling interval based on active builds
            adjustPollingInterval()
            
        } catch let apiError as VercelAPIService.APIError {
            handleAPIError(apiError)
        } catch {
            self.errorMessage = error.localizedDescription
            self.activeAPIError = .networkError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func handleAPIError(_ error: VercelAPIService.APIError) {
        self.activeAPIError = error
        self.errorMessage = error.localizedDescription
        
        switch error {
        case .unauthorized, .missingToken:
            self.isAuthenticated = false
            self.stopPolling()
            
        case .rateLimited(let retryAfter):
            let cooldown = TimeInterval(retryAfter ?? 60)
            self.rateLimitResetDate = Date().addingTimeInterval(cooldown)
            // Schedule timer after rate limit reset
            reschedulePolling(interval: max(5.0, cooldown))
            
        default:
            break
        }
    }
    
    // MARK: - Filtering Logic
    
    public func updateFilteredDeployments() {
        switch selectedScope {
        case .all:
            filteredDeployments = deployments
        case .production:
            filteredDeployments = deployments.filter { $0.isProduction }
        case .preview:
            filteredDeployments = deployments.filter { $0.isPreview }
        }
    }
    
    // MARK: - Adaptive Polling Engine
    
    /// Computes the required polling interval given the current deployment states.
    public func computePollingInterval() -> TimeInterval {
        if let reset = rateLimitResetDate, reset > Date() {
            return max(5.0, reset.timeIntervalSinceNow)
        }
        return hasActiveBuilds ? activePollingInterval : basePollingInterval
    }
    
    /// Starts or restarts the adaptive polling timer.
    public func startPolling() {
        stopPolling()
        let interval = computePollingInterval()
        currentPollingInterval = interval
        
        pollingTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isAuthenticated else { return }
                Task {
                    await self.fetchAllData()
                }
            }
    }
    
    /// Re-evaluates whether the polling interval should accelerate (to 10s) or relax (to 60s).
    public func adjustPollingInterval() {
        let neededInterval = computePollingInterval()
        if abs(currentPollingInterval - neededInterval) > 0.5 {
            reschedulePolling(interval: neededInterval)
        }
    }
    
    private func reschedulePolling(interval: TimeInterval) {
        currentPollingInterval = interval
        pollingTimer?.cancel()
        
        pollingTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isAuthenticated else { return }
                Task {
                    await self.fetchAllData()
                }
            }
    }
    
    /// Alias for backwards compatibility.
    public func startTimer() {
        startPolling()
    }
    
    /// Alias for backwards compatibility.
    public func stopTimer() {
        stopPolling()
    }
    
    public func stopPolling() {
        pollingTimer?.cancel()
        pollingTimer = nil
    }
}
