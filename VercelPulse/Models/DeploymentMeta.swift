import Foundation

/// Git commit and repository metadata associated with a Vercel deployment.
public struct DeploymentMeta: Codable, Hashable, Sendable {
    public let githubCommitMessage: String?
    public let githubCommitRef: String?
    public let githubCommitAuthorName: String?
    public let githubCommitAuthorLogin: String?
    public let githubCommitSha: String?
    public let githubCommitOrg: String?
    public let githubCommitRepo: String?
    public let gitlabCommitMessage: String?
    public let bitbucketCommitMessage: String?
    public let branchAlias: String?
    
    public init(
        githubCommitMessage: String? = nil,
        githubCommitRef: String? = nil,
        githubCommitAuthorName: String? = nil,
        githubCommitAuthorLogin: String? = nil,
        githubCommitSha: String? = nil,
        githubCommitOrg: String? = nil,
        githubCommitRepo: String? = nil,
        gitlabCommitMessage: String? = nil,
        bitbucketCommitMessage: String? = nil,
        branchAlias: String? = nil
    ) {
        self.githubCommitMessage = githubCommitMessage
        self.githubCommitRef = githubCommitRef
        self.githubCommitAuthorName = githubCommitAuthorName
        self.githubCommitAuthorLogin = githubCommitAuthorLogin
        self.githubCommitSha = githubCommitSha
        self.githubCommitOrg = githubCommitOrg
        self.githubCommitRepo = githubCommitRepo
        self.gitlabCommitMessage = gitlabCommitMessage
        self.bitbucketCommitMessage = bitbucketCommitMessage
        self.branchAlias = branchAlias
    }
    
    /// Normalized commit message across git providers.
    public var commitMessage: String? {
        githubCommitMessage ?? gitlabCommitMessage ?? bitbucketCommitMessage
    }
    
    /// Normalized branch name.
    public var branchName: String? {
        githubCommitRef
    }
    
    /// Normalized author display name.
    public var authorName: String? {
        githubCommitAuthorName ?? githubCommitAuthorLogin
    }
    
    /// Abbreviated 7-character commit SHA.
    public var shortSha: String? {
        guard let sha = githubCommitSha, sha.count >= 7 else { return githubCommitSha }
        return String(sha.prefix(7))
    }
}
