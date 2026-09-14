import Foundation

/// Pagination metadata returned by Vercel list endpoints.
public struct Pagination: Codable, Equatable, Sendable {
    public let count: Int
    public let next: Int64?
    public let prev: Int64?
    
    public init(count: Int = 0, next: Int64? = nil, prev: Int64? = nil) {
        self.count = count
        self.next = next
        self.prev = prev
    }
}

/// Response payload envelope for GET /v6/deployments.
public struct DeploymentsResponse: Codable, Equatable, Sendable {
    public let deployments: [Deployment]
    public let pagination: Pagination?
    
    public init(deployments: [Deployment] = [], pagination: Pagination? = nil) {
        self.deployments = deployments
        self.pagination = pagination
    }
    
    enum CodingKeys: String, CodingKey {
        case deployments
        case pagination
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deployments = (try? container.decode([Deployment].self, forKey: .deployments)) ?? []
        self.pagination = try? container.decode(Pagination.self, forKey: .pagination)
    }
}
