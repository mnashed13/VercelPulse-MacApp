import Foundation

struct Project: Decodable, Identifiable {
    let id: String
    let name: String
    let framework: String?
    let link: ProjectLink?
    
    struct ProjectLink: Decodable {
        let type: String?
        let repo: String?
        let org: String?
    }
}
