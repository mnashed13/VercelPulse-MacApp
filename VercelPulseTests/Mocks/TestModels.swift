import Foundation
import CryptoKit

// Domain state enum matching PROJECT.md
public enum TestDeploymentState: String, Codable, CaseIterable {
    case initializing = "INITIALIZING"
    case queued = "QUEUED"
    case building = "BUILDING"
    case ready = "READY"
    case error = "ERROR"
    case canceled = "CANCELED"
    case unknown = "UNKNOWN"
    
    public init(apiState: String?) {
        guard let state = apiState?.uppercased() else {
            self = .unknown
            return
        }
        self = TestDeploymentState(rawValue: state) ?? .unknown
    }
    
    public var isActive: Bool {
        return self == .building || self == .queued || self == .initializing
    }
    
    public var isFinal: Bool {
        return self == .ready || self == .error || self == .canceled
    }
    
    public var statusBadgeColorName: String {
        switch self {
        case .ready: return "systemGreen"
        case .building, .queued, .initializing: return "systemBlue"
        case .error: return "systemRed"
        case .canceled: return "systemGray"
        case .unknown: return "systemGray"
        }
    }
}

public struct TestDeploymentMeta: Codable, Equatable {
    public let githubCommitMessage: String?
    public let githubCommitRef: String?
    public let githubCommitSha: String?
    public let githubCommitAuthorName: String?
    
    public init(
        githubCommitMessage: String? = nil,
        githubCommitRef: String? = nil,
        githubCommitSha: String? = nil,
        githubCommitAuthorName: String? = nil
    ) {
        self.githubCommitMessage = githubCommitMessage
        self.githubCommitRef = githubCommitRef
        self.githubCommitSha = githubCommitSha
        self.githubCommitAuthorName = githubCommitAuthorName
    }
}

public struct TestDeploymentCreator: Codable, Equatable {
    public let username: String?
    
    public init(username: String? = nil) {
        self.username = username
    }
}

public struct TestDeployment: Codable, Identifiable, Equatable {
    public let uid: String
    public let name: String
    public let url: String
    public let state: String
    public let created: Int64
    public let creator: TestDeploymentCreator?
    public let meta: TestDeploymentMeta?
    public let target: String?
    
    public var id: String { uid }
    public var typedState: TestDeploymentState { TestDeploymentState(apiState: state) }
    
    public var isProduction: Bool {
        if let target = target {
            return target.lowercased() == "production"
        }
        return meta?.githubCommitRef == "main" || meta?.githubCommitRef == "master"
    }
    
    public var isPreview: Bool {
        return !isProduction
    }
    
    public init(
        uid: String,
        name: String,
        url: String,
        state: String,
        created: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        creator: TestDeploymentCreator? = nil,
        meta: TestDeploymentMeta? = nil,
        target: String? = "preview"
    ) {
        self.uid = uid
        self.name = name
        self.url = url
        self.state = state
        self.created = created
        self.creator = creator
        self.meta = meta
        self.target = target
    }
}

public struct TestPagination: Codable, Equatable {
    public let count: Int
    public let next: Int64?
    public let prev: Int64?
    
    public init(count: Int, next: Int64? = nil, prev: Int64? = nil) {
        self.count = count
        self.next = next
        self.prev = prev
    }
}

public struct TestDeploymentsResponse: Codable, Equatable {
    public let deployments: [TestDeployment]
    public let pagination: TestPagination?
    
    public init(deployments: [TestDeployment], pagination: TestPagination? = nil) {
        self.deployments = deployments
        self.pagination = pagination
    }
}

public struct TestProjectLink: Codable, Equatable {
    public let type: String?
    public let repo: String?
    public let org: String?
    
    public init(type: String? = nil, repo: String? = nil, org: String? = nil) {
        self.type = type
        self.repo = repo
        self.org = org
    }
}

public struct TestProject: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let framework: String?
    public let link: TestProjectLink?
    
    public init(id: String, name: String, framework: String? = nil, link: TestProjectLink? = nil) {
        self.id = id
        self.name = name
        self.framework = framework
        self.link = link
    }
}

public struct TestUsageMetricDetail: Codable, Equatable {
    public let limit: Int?
    public let usage: Int?
    
    public init(limit: Int?, usage: Int?) {
        self.limit = limit
        self.usage = usage
    }
}

public struct TestUsage: Codable, Equatable {
    public let metrics: [String: TestUsageMetricDetail]?
    
    public init(metrics: [String: TestUsageMetricDetail]? = nil) {
        self.metrics = metrics
    }
}

// PKCE RFC 7636 Helper
public enum TestPKCEHelper {
    public static func generateCodeVerifier(length: Int = 64) -> String {
        let validChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        let clampedLength = min(max(length, 43), 128)
        var result = ""
        for _ in 0..<clampedLength {
            let randomIndex = Int.random(in: 0..<validChars.count)
            let charIndex = validChars.index(validChars.startIndex, offsetBy: randomIndex)
            result.append(validChars[charIndex])
        }
        return result
    }
    
    public static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

// Deep Linking Builder matching R3.2 and PROJECT.md §11
public enum TestDeepLinkHelper {
    public static func inspectorURL(teamSlug: String?, projectName: String, deploymentId: String) -> URL? {
        let team = (teamSlug != nil && !teamSlug!.isEmpty) ? teamSlug! : "~"
        let urlString = "https://vercel.com/\(team)/\(projectName)/\(deploymentId)"
        return URL(string: urlString)
    }
    
    public static func previewURL(domain: String) -> URL? {
        var clean = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.starts(with: "http://") && !clean.starts(with: "https://") {
            clean = "https://" + clean
        }
        return URL(string: clean)
    }
    
    public static func commitURL(org: String, repo: String, sha: String) -> URL? {
        guard !org.isEmpty, !repo.isEmpty, !sha.isEmpty else { return nil }
        return URL(string: "https://github.com/\(org)/\(repo)/commit/\(sha)")
    }
}

// Adaptive Polling Strategy Helper
public enum TestPollingEngine {
    public static func computePollingInterval(for deployments: [TestDeployment]) -> TimeInterval {
        let hasActive = deployments.contains { $0.typedState.isActive }
        return hasActive ? 10.0 : 60.0
    }
}
