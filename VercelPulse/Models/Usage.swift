import Foundation

public struct Usage: Codable, Equatable, Sendable {
    public let metrics: [String: MetricDetail]?
    
    public init(metrics: [String: MetricDetail]? = nil) {
        self.metrics = metrics
    }
    
    public struct MetricDetail: Codable, Equatable, Sendable {
        public let limit: Int?
        public let usage: Int?
        
        public init(limit: Int? = nil, usage: Int? = nil) {
            self.limit = limit
            self.usage = usage
        }
    }
}
