import Foundation

/// Protocol defining Vercel REST API networking operations.
public protocol VercelAPIServicing: AnyObject {
    /// Fetches deployments with filtering and pagination parameters.
    func fetchDeployments(
        teamId: String?,
        projectId: String?,
        limit: Int?,
        until: Int64?,
        since: Int64?,
        state: String?,
        target: String?
    ) async throws -> DeploymentsResponse
    
    /// Fetches deployments with basic cursor pagination and project scoping.
    func fetchDeployments(
        teamId: String?,
        projectId: String?,
        limit: Int?,
        until: Int64?
    ) async throws -> DeploymentsResponse
    
    /// Fetches projects in the user or team workspace.
    func fetchProjects(teamId: String?) async throws -> [Project]
    
    /// Fetches account/team usage metrics.
    func fetchUsage(teamId: String?) async throws -> Usage
}

public extension VercelAPIServicing {
    func fetchDeployments(
        teamId: String? = nil,
        projectId: String? = nil,
        limit: Int? = nil,
        until: Int64? = nil
    ) async throws -> DeploymentsResponse {
        try await fetchDeployments(
            teamId: teamId,
            projectId: projectId,
            limit: limit,
            until: until,
            since: nil,
            state: nil,
            target: nil
        )
    }
    
    func fetchProjects() async throws -> [Project] {
        try await fetchProjects(teamId: nil)
    }
    
    func fetchUsage() async throws -> Usage {
        try await fetchUsage(teamId: nil)
    }
}

/// Production REST API client for Vercel endpoints with 401 retry interception.
public final class VercelAPIService: VercelAPIServicing {
    
    // MARK: - Shared Singleton
    public static let shared = VercelAPIService()
    
    // MARK: - Typed Errors
    public enum APIError: Error, LocalizedError, Equatable {
        case missingToken
        case invalidURL
        case unauthorized
        case forbidden
        case notFound
        case rateLimited(retryAfter: Int?)
        case serverError(statusCode: Int, message: String?)
        case networkError(String)
        case decodingFailed(String)
        case requestFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .missingToken:
                return "No API token found. Please sign in or add a token in settings."
            case .invalidURL:
                return "Invalid URL constructed."
            case .unauthorized:
                return "Unauthorized: API token expired or invalid."
            case .forbidden:
                return "Forbidden: Insufficient permissions or invalid team access."
            case .notFound:
                return "Resource not found on Vercel."
            case .rateLimited(let retryAfter):
                if let retry = retryAfter {
                    return "Vercel API rate limit exceeded. Retry after \(retry) seconds."
                }
                return "Vercel API rate limit exceeded. Please try again later."
            case .serverError(let statusCode, let message):
                return "Vercel server error (\(statusCode)): \(message ?? "Internal error")"
            case .networkError(let details):
                return "Network error: \(details)"
            case .decodingFailed(let details):
                return "Failed to decode response: \(details)"
            case .requestFailed(let message):
                return "Request failed: \(message)"
            }
        }
    }
    
    // MARK: - Dependencies
    public let baseURL: String
    public let session: URLSession
    public let keychain: KeychainManaging
    public weak var oauthService: VercelOAuthServicing?
    public var tokenRefresher: (() async throws -> OAuthToken)?
    
    // MARK: - Initializer
    public init(
        baseURL: String = "https://api.vercel.com",
        session: URLSession = .shared,
        keychain: KeychainManaging = KeychainManager.shared,
        oauthService: VercelOAuthServicing? = nil,
        tokenRefresher: (() async throws -> OAuthToken)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
        self.oauthService = oauthService
        self.tokenRefresher = tokenRefresher
    }
    
    // MARK: - Public API Methods
    
    public func fetchDeployments(
        teamId: String? = nil,
        projectId: String? = nil,
        limit: Int? = nil,
        until: Int64? = nil,
        since: Int64? = nil,
        state: String? = nil,
        target: String? = nil
    ) async throws -> DeploymentsResponse {
        var queryItems: [URLQueryItem] = []
        
        if let teamId = teamId, !teamId.isEmpty {
            queryItems.append(URLQueryItem(name: "teamId", value: teamId))
        }
        if let projectId = projectId, !projectId.isEmpty {
            queryItems.append(URLQueryItem(name: "projectId", value: projectId))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let until = until {
            queryItems.append(URLQueryItem(name: "until", value: String(until)))
        }
        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: String(since)))
        }
        if let state = state, !state.isEmpty {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        if let target = target, !target.isEmpty {
            queryItems.append(URLQueryItem(name: "target", value: target))
        }
        
        return try await executeRequest(endpoint: "/v6/deployments", queryItems: queryItems)
    }
    
    public func fetchDeployments(
        teamId: String?,
        projectId: String?,
        limit: Int?,
        until: Int64?
    ) async throws -> DeploymentsResponse {
        try await fetchDeployments(
            teamId: teamId,
            projectId: projectId,
            limit: limit,
            until: until,
            since: nil,
            state: nil,
            target: nil
        )
    }
    
    /// Convenience helper returning list of deployments.
    public func fetchDeployments() async throws -> [Deployment] {
        let response: DeploymentsResponse = try await fetchDeployments(teamId: nil, projectId: nil, limit: 20, until: nil)
        return response.deployments
    }
    
    public func fetchProjects(teamId: String? = nil) async throws -> [Project] {
        var queryItems: [URLQueryItem] = []
        if let teamId = teamId, !teamId.isEmpty {
            queryItems.append(URLQueryItem(name: "teamId", value: teamId))
        }
        
        struct ProjectsResponse: Decodable {
            let projects: [Project]
        }
        
        let response: ProjectsResponse = try await executeRequest(endpoint: "/v9/projects", queryItems: queryItems)
        return response.projects
    }
    
    public func fetchProjects() async throws -> [Project] {
        try await fetchProjects(teamId: nil)
    }
    
    public func fetchUsage(teamId: String? = nil) async throws -> Usage {
        var queryItems: [URLQueryItem] = []
        if let teamId = teamId, !teamId.isEmpty {
            queryItems.append(URLQueryItem(name: "teamId", value: teamId))
        }
        return try await executeRequest(endpoint: "/v2/usage", queryItems: queryItems)
    }
    
    public func fetchUsage() async throws -> Usage {
        try await fetchUsage(teamId: nil)
    }
    
    // MARK: - Private Request Pipeline with 401 Retry Interceptor
    
    private func executeRequest<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        isRetry: Bool = false
    ) async throws -> T {
        // 1. Resolve access token
        guard let token = resolveAccessToken(), !token.isEmpty else {
            throw APIError.missingToken
        }
        
        // 2. Build URL with query items and fallback team scoping
        var components = URLComponents(string: baseURL + endpoint)
        guard components != nil else {
            throw APIError.invalidURL
        }
        
        var effectiveQueryItems = queryItems
        // Apply teamId fallback if not explicitly provided in queryItems
        let hasTeamId = effectiveQueryItems.contains { $0.name == "teamId" }
        if !hasTeamId {
            if let savedTeamId = UserDefaults.standard.string(forKey: "teamId"), !savedTeamId.isEmpty {
                effectiveQueryItems.append(URLQueryItem(name: "teamId", value: savedTeamId))
            } else if let tokenTeamId = keychain.getToken()?.teamId, !tokenTeamId.isEmpty {
                effectiveQueryItems.append(URLQueryItem(name: "teamId", value: tokenTeamId))
            }
        }
        
        if !effectiveQueryItems.isEmpty {
            components?.queryItems = effectiveQueryItems
        }
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        // 3. Assemble URLRequest
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 4. Perform Network Request
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError.localizedDescription)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed("Invalid HTTP response")
        }
        
        // 5. Handle Status Codes
        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed(error.localizedDescription)
            }
            
        case 401:
            // Attempt reactive token refresh and request replay once
            if !isRetry {
                let refreshed = await attemptTokenRefresh()
                if refreshed {
                    return try await executeRequest(endpoint: endpoint, queryItems: queryItems, isRetry: true)
                }
            }
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        case 429:
            let retryAfterHeader = httpResponse.value(forHTTPHeaderField: "Retry-After")
            let retryAfter = retryAfterHeader.flatMap { Int($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
            
        case 500..<600:
            let errorMsg = extractErrorMessage(from: data) ?? "Internal server error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
            
        default:
            let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw APIError.requestFailed(errorMsg)
        }
    }
    
    // MARK: - Private Helpers
    
    private func resolveAccessToken() -> String? {
        if let token = keychain.getToken()?.accessToken, !token.isEmpty {
            return token
        }
        if let legacy = keychain.getString(key: KeychainKeys.legacyToken), !legacy.isEmpty {
            return legacy
        }
        return nil
    }
    
    private func attemptTokenRefresh() async -> Bool {
        if let oauth = oauthService {
            do {
                _ = try await oauth.refreshToken()
                return true
            } catch {
                return false
            }
        }
        if let refresher = tokenRefresher {
            do {
                _ = try await refresher()
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorDict = json["error"] as? [String: Any],
           let message = errorDict["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8)
    }
}
