import Foundation

/// Information regarding the creator of a deployment.
public struct DeploymentCreator: Codable, Hashable, Sendable {
    public let uid: String?
    public let username: String?
    public let email: String?
    public let githubLogin: String?
    
    public init(
        uid: String? = nil,
        username: String? = nil,
        email: String? = nil,
        githubLogin: String? = nil
    ) {
        self.uid = uid
        self.username = username
        self.email = email
        self.githubLogin = githubLogin
    }
}

/// Rich domain model representing a Vercel deployment.
public struct Deployment: Identifiable, Codable, Hashable, Sendable {
    public let uid: String
    public let name: String
    public let url: String
    public let state: String
    public let readyState: DeploymentState?
    public let type: String?
    public let target: String?
    public let inspectorUrl: String?
    public let projectId: String?
    public let created: Int64
    public let ready: Int64?
    public let buildingAt: Int64?
    public let creator: DeploymentCreator?
    public let meta: DeploymentMeta?
    
    public var id: String { uid }
    
    /// Unique identity including lifecycle status to ensure SwiftUI re-renders upon state transitions.
    public var idAndState: String {
        "\(uid)_\(status.rawValue)_\(ready ?? 0)_\(buildingAt ?? 0)"
    }
    
    /// Typed lifecycle status of the deployment.
    public var status: DeploymentState {
        if let readyState = readyState, readyState != .unknown {
            return readyState
        }
        let fromState = DeploymentState(apiState: state)
        if fromState != .unknown {
            return fromState
        }
        return readyState ?? .unknown
    }
    
    /// Alias for typed status matching test harnesses.
    public var typedState: DeploymentState {
        status
    }
    
    /// Indicates whether the deployment was targeted for production.
    public var isProduction: Bool {
        if let target = target {
            return target.lowercased() == "production"
        }
        return meta?.githubCommitRef == "main" || meta?.githubCommitRef == "master"
    }
    
    /// Indicates whether the deployment is a preview or development build.
    public var isPreview: Bool {
        !isProduction
    }
    
    /// Formatted relative creation timestamp (e.g. "3m ago").
    public var relativeCreatedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(created) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Formatted build duration string (e.g. "42s", "1m 15s").
    public var durationFormatted: String? {
        guard let readyTimestamp = ready, readyTimestamp > created else {
            if status.isInProgress {
                let startMs = buildingAt ?? created
                let elapsedSeconds = max(0, Int((Date().timeIntervalSince1970 * 1000 - Double(startMs)) / 1000))
                return formatSeconds(elapsedSeconds)
            }
            return nil
        }
        let totalSeconds = Int((readyTimestamp - created) / 1000)
        return formatSeconds(totalSeconds)
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remSeconds = seconds % 60
        return "\(minutes)m \(remSeconds)s"
    }
    
    public init(
        uid: String,
        name: String,
        url: String,
        state: String? = nil,
        readyState: DeploymentState? = nil,
        type: String? = nil,
        target: String? = "preview",
        inspectorUrl: String? = nil,
        projectId: String? = nil,
        created: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        ready: Int64? = nil,
        buildingAt: Int64? = nil,
        creator: DeploymentCreator? = nil,
        meta: DeploymentMeta? = nil
    ) {
        self.uid = uid
        self.name = name
        self.url = url
        self.state = state ?? readyState?.rawValue ?? "UNKNOWN"
        self.readyState = readyState ?? (state != nil ? DeploymentState(apiState: state) : .unknown)
        self.type = type
        self.target = target
        self.inspectorUrl = inspectorUrl
        self.projectId = projectId
        self.created = created
        self.ready = ready
        self.buildingAt = buildingAt
        self.creator = creator
        self.meta = meta
    }
    
    enum CodingKeys: String, CodingKey {
        case uid
        case name
        case url
        case state
        case readyState
        case status
        case type
        case target
        case inspectorUrl
        case projectId
        case created
        case ready
        case buildingAt
        case creator
        case meta
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uid = try container.decode(String.self, forKey: .uid)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = (try? container.decode(String.self, forKey: .url)) ?? ""
        
        let rawState = try? container.decode(String.self, forKey: .state)
        let rawReadyState = try? container.decode(DeploymentState.self, forKey: .readyState)
        let rawStatus = try? container.decode(DeploymentState.self, forKey: .status)
        
        let resolvedReadyState: DeploymentState
        if let r = rawReadyState, r != .unknown {
            resolvedReadyState = r
        } else if let s = rawStatus, s != .unknown {
            resolvedReadyState = s
        } else if let st = rawState {
            resolvedReadyState = DeploymentState(apiState: st)
        } else {
            resolvedReadyState = .unknown
        }
        
        self.readyState = resolvedReadyState
        self.state = rawState ?? resolvedReadyState.rawValue
        
        self.type = try? container.decode(String.self, forKey: .type)
        self.target = try? container.decode(String.self, forKey: .target)
        self.inspectorUrl = try? container.decode(String.self, forKey: .inspectorUrl)
        self.projectId = try? container.decode(String.self, forKey: .projectId)
        self.created = try container.decode(Int64.self, forKey: .created)
        self.ready = try? container.decode(Int64.self, forKey: .ready)
        self.buildingAt = try? container.decode(Int64.self, forKey: .buildingAt)
        self.creator = try? container.decode(DeploymentCreator.self, forKey: .creator)
        self.meta = try? container.decode(DeploymentMeta.self, forKey: .meta)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uid, forKey: .uid)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(readyState, forKey: .readyState)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encodeIfPresent(inspectorUrl, forKey: .inspectorUrl)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(ready, forKey: .ready)
        try container.encodeIfPresent(buildingAt, forKey: .buildingAt)
        try container.encodeIfPresent(creator, forKey: .creator)
        try container.encodeIfPresent(meta, forKey: .meta)
    }
    
    public static func == (lhs: Deployment, rhs: Deployment) -> Bool {
        lhs.uid == rhs.uid &&
        lhs.state == rhs.state &&
        lhs.readyState == rhs.readyState &&
        lhs.url == rhs.url &&
        lhs.ready == rhs.ready &&
        lhs.buildingAt == rhs.buildingAt &&
        lhs.target == rhs.target &&
        lhs.meta == rhs.meta
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
        hasher.combine(state)
        hasher.combine(readyState)
        hasher.combine(ready)
        hasher.combine(buildingAt)
    }
}
