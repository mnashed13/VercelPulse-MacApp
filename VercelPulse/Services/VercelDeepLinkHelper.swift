import Foundation
import AppKit

/// Generates deep links for Vercel Web Dashboard inspector pages, preview domains, and Git commits.
public struct VercelDeepLinkHelper {
    
    /// Resolves the inspector URL for a deployment using multi-tier fallback:
    /// 1. `deployment.inspectorUrl` if present.
    /// 2. `https://vercel.com/[teamSlugOrUsername]/[projectName]/[deploymentUid]` (or `~` for personal accounts).
    /// 3. `https://vercel.com/deployments/[deploymentUid]` as fallback.
    public static func webDashboardURL(
        for deployment: Deployment,
        teamSlug: String? = nil,
        username: String? = nil
    ) -> URL {
        if let inspector = deployment.inspectorUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           !inspector.isEmpty,
           let url = URL(string: inspector) {
            return url
        }
        
        let team = (teamSlug != nil && !teamSlug!.isEmpty) ? teamSlug! : (username ?? "~")
        let path = "https://vercel.com/\(team)/\(deployment.name)/\(deployment.uid)"
        if let url = URL(string: path) {
            return url
        }
        
        return URL(string: "https://vercel.com/deployments/\(deployment.uid)")!
    }
    
    /// Constructs an inspector URL from explicit component values.
    public static func inspectorURL(teamSlug: String?, projectName: String, deploymentId: String) -> URL? {
        let team = (teamSlug != nil && !teamSlug!.isEmpty) ? teamSlug! : "~"
        let urlString = "https://vercel.com/\(team)/\(projectName)/\(deploymentId)"
        return URL(string: urlString)
    }
    
    /// Constructs a safe HTTPS preview URL for a deployment.
    public static func previewURL(for deployment: Deployment) -> URL? {
        return previewURL(domain: deployment.url)
    }
    
    /// Constructs a safe HTTPS preview URL for a raw domain string.
    public static func previewURL(domain: String) -> URL? {
        var clean = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if !clean.starts(with: "http://") && !clean.starts(with: "https://") {
            clean = "https://" + clean
        }
        return URL(string: clean)
    }
    
    /// Constructs a GitHub commit URL from deployment metadata.
    public static func gitCommitURL(for meta: DeploymentMeta?) -> URL? {
        guard let org = meta?.githubCommitOrg, !org.isEmpty,
              let repo = meta?.githubCommitRepo, !repo.isEmpty,
              let sha = meta?.githubCommitSha, !sha.isEmpty else {
            return nil
        }
        return commitURL(org: org, repo: repo, sha: sha)
    }
    
    /// Constructs a GitHub commit URL from org, repo, and commit SHA.
    public static func commitURL(org: String, repo: String, sha: String) -> URL? {
        guard !org.isEmpty, !repo.isEmpty, !sha.isEmpty else { return nil }
        return URL(string: "https://github.com/\(org)/\(repo)/commit/\(sha)")
    }
    
    /// Opens the specified URL in the system's default browser.
    public static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
