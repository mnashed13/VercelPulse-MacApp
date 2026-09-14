import Foundation

public struct Project: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let framework: String?
    public let link: ProjectLink?
    
    public init(id: String, name: String, framework: String? = nil, link: ProjectLink? = nil) {
        self.id = id
        self.name = name
        self.framework = framework
        self.link = link
    }
    
    public struct ProjectLink: Codable, Equatable, Sendable {
        public let type: String?
        public let repo: String?
        public let org: String?
        
        public init(type: String? = nil, repo: String? = nil, org: String? = nil) {
            self.type = type
            self.repo = repo
            self.org = org
        }
    }
}
