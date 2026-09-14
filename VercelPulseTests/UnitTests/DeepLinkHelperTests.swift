import XCTest
@testable import VercelPulse

final class DeepLinkHelperTests: XCTestCase {
    
    // MARK: - TestDeepLinkHelper Tests
    
    func testInspectorURLWithTeamScoping() {
        let teamURL = TestDeepLinkHelper.inspectorURL(
            teamSlug: "team_alpha_prod",
            projectName: "nextjs-storefront",
            deploymentId: "dpl_abc123"
        )
        XCTAssertEqual(teamURL?.absoluteString, "https://vercel.com/team_alpha_prod/nextjs-storefront/dpl_abc123")
    }
    
    func testInspectorURLWithPersonalAccountTilde() {
        let personalURL = TestDeepLinkHelper.inspectorURL(
            teamSlug: nil,
            projectName: "nextjs-storefront",
            deploymentId: "dpl_abc123"
        )
        XCTAssertEqual(personalURL?.absoluteString, "https://vercel.com/~/nextjs-storefront/dpl_abc123")
        
        let emptyTeamURL = TestDeepLinkHelper.inspectorURL(
            teamSlug: "",
            projectName: "nextjs-storefront",
            deploymentId: "dpl_abc123"
        )
        XCTAssertEqual(emptyTeamURL?.absoluteString, "https://vercel.com/~/nextjs-storefront/dpl_abc123")
    }
    
    func testPreviewURLResolution() {
        let cleanURL = TestDeepLinkHelper.previewURL(domain: "my-app.vercel.app")
        XCTAssertEqual(cleanURL?.absoluteString, "https://my-app.vercel.app")
        
        let alreadyHttps = TestDeepLinkHelper.previewURL(domain: "https://my-app.vercel.app")
        XCTAssertEqual(alreadyHttps?.absoluteString, "https://my-app.vercel.app")
        
        let trimmedURL = TestDeepLinkHelper.previewURL(domain: "  my-app.vercel.app \n")
        XCTAssertEqual(trimmedURL?.absoluteString, "https://my-app.vercel.app")
    }
    
    func testCommitURLResolution() {
        let commitURL = TestDeepLinkHelper.commitURL(
            org: "vercel",
            repo: "next.js",
            sha: "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e"
        )
        XCTAssertEqual(
            commitURL?.absoluteString,
            "https://github.com/vercel/next.js/commit/a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e"
        )
        
        let emptySha = TestDeepLinkHelper.commitURL(org: "vercel", repo: "next.js", sha: "")
        XCTAssertNil(emptySha)
    }
    
    // MARK: - VercelDeepLinkHelper Production Struct Tests
    
    func testVercelDeepLinkHelper_WebDashboardURL_WithDirectInspectorURL() {
        let deployment = Deployment(
            uid: "dpl_direct_123",
            name: "web-app",
            url: "web-app.vercel.app",
            inspectorUrl: "https://vercel.com/team-special/web-app/dpl_direct_123"
        )
        let url = VercelDeepLinkHelper.webDashboardURL(for: deployment)
        XCTAssertEqual(url.absoluteString, "https://vercel.com/team-special/web-app/dpl_direct_123")
    }
    
    func testVercelDeepLinkHelper_WebDashboardURL_WithTeamSlugFallback() {
        let deployment = Deployment(
            uid: "dpl_team_456",
            name: "pulse-docs",
            url: "pulse-docs.vercel.app",
            inspectorUrl: nil
        )
        let url = VercelDeepLinkHelper.webDashboardURL(for: deployment, teamSlug: "acme-corp")
        XCTAssertEqual(url.absoluteString, "https://vercel.com/acme-corp/pulse-docs/dpl_team_456")
    }
    
    func testVercelDeepLinkHelper_WebDashboardURL_WithUsernameFallback() {
        let deployment = Deployment(
            uid: "dpl_user_789",
            name: "personal-blog",
            url: "personal-blog.vercel.app",
            inspectorUrl: nil
        )
        let url = VercelDeepLinkHelper.webDashboardURL(for: deployment, username: "michaelnashed")
        XCTAssertEqual(url.absoluteString, "https://vercel.com/michaelnashed/personal-blog/dpl_user_789")
    }
    
    func testVercelDeepLinkHelper_WebDashboardURL_WithTildeFallback() {
        let deployment = Deployment(
            uid: "dpl_fallback_001",
            name: "quick-test",
            url: "quick-test.vercel.app",
            inspectorUrl: nil
        )
        let url = VercelDeepLinkHelper.webDashboardURL(for: deployment)
        XCTAssertEqual(url.absoluteString, "https://vercel.com/~/quick-test/dpl_fallback_001")
    }
    
    func testVercelDeepLinkHelper_PreviewURL_Sanitization() {
        let deployment = Deployment(
            uid: "dpl_1",
            name: "app",
            url: "  sub.domain.vercel.app \n"
        )
        let preview = VercelDeepLinkHelper.previewURL(for: deployment)
        XCTAssertEqual(preview?.absoluteString, "https://sub.domain.vercel.app")
        
        let emptyDeployment = Deployment(uid: "dpl_empty", name: "empty", url: "")
        XCTAssertNil(VercelDeepLinkHelper.previewURL(for: emptyDeployment))
    }
    
    func testVercelDeepLinkHelper_GitCommitURL() {
        let meta = DeploymentMeta(
            githubCommitSha: "deadbeef1234567890",
            githubCommitOrg: "vercel",
            githubCommitRepo: "vercelpulse"
        )
        let commitURL = VercelDeepLinkHelper.gitCommitURL(for: meta)
        XCTAssertEqual(commitURL?.absoluteString, "https://github.com/vercel/vercelpulse/commit/deadbeef1234567890")
        
        let incompleteMeta = DeploymentMeta(
            githubCommitSha: "",
            githubCommitOrg: "vercel",
            githubCommitRepo: "vercelpulse"
        )
        XCTAssertNil(VercelDeepLinkHelper.gitCommitURL(for: incompleteMeta))
    }
}
