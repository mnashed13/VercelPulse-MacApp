import Foundation

struct Deployment: Decodable, Identifiable {
    let uid: String
    let name: String
    let url: String
    let state: String
    let creator: Creator?
    let meta: Meta?
    let created: Int64
    
    var id: String { uid }
    
    struct Creator: Decodable {
        let username: String?
    }
    
    struct Meta: Decodable {
        let githubCommitMessage: String?
        let githubCommitRef: String?
        
        enum CodingKeys: String, CodingKey {
            case githubCommitMessage
            case githubCommitRef
        }
    }
}
