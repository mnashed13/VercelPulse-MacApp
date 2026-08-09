import Foundation

class VercelAPIService {
    static let shared = VercelAPIService()
    
    private let baseURL = "https://api.vercel.com"
    
    enum APIError: Error, LocalizedError {
        case missingToken
        case invalidURL
        case requestFailed(String)
        case decodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .missingToken: return "No API token found. Please add it in settings."
            case .invalidURL: return "Invalid URL constructed."
            case .requestFailed(let message): return "Request failed: \(message)"
            case .decodingFailed(let error): return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }
    
    private func getTeamIdQueryString() -> String {
        let defaults = UserDefaults.standard
        if let teamId = defaults.string(forKey: "teamId"), !teamId.isEmpty {
            return "?teamId=\(teamId)"
        }
        return ""
    }
    
    private func fetch<T: Decodable>(endpoint: String) async throws -> T {
        guard let token = KeychainManager.shared.getToken(), !token.isEmpty else {
            throw APIError.missingToken
        }
        
        let teamQuery = getTeamIdQueryString()
        var fullEndpoint = endpoint
        if !teamQuery.isEmpty {
            if fullEndpoint.contains("?") {
                fullEndpoint += "&" + teamQuery.replacingOccurrences(of: "?", with: "")
            } else {
                fullEndpoint += teamQuery
            }
        }
        
        guard let url = URL(string: baseURL + fullEndpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed("Invalid HTTP response")
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw APIError.requestFailed(errorMsg)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    func fetchProjects() async throws -> [Project] {
        struct ProjectsResponse: Decodable {
            let projects: [Project]
        }
        let response: ProjectsResponse = try await fetch(endpoint: "/v9/projects")
        return response.projects
    }
    
    func fetchDeployments() async throws -> [Deployment] {
        struct DeploymentsResponse: Decodable {
            let deployments: [Deployment]
        }
        let response: DeploymentsResponse = try await fetch(endpoint: "/v6/deployments?limit=10")
        return response.deployments
    }
    
    func fetchUsage() async throws -> Usage {
        return try await fetch(endpoint: "/v2/usage")
    }
}
