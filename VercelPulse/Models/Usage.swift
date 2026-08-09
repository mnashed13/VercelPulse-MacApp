import Foundation

struct Usage: Decodable {
    let metrics: [String: MetricDetail]?
    
    struct MetricDetail: Decodable {
        let limit: Int?
        let usage: Int?
    }
}
