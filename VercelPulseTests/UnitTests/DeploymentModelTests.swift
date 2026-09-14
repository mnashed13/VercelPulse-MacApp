import XCTest
@testable import VercelPulse

final class DeploymentModelTests: XCTestCase {
    
    // MARK: - DeploymentState Enum Tests
    
    func testDeploymentState_RawValuesAndDecoding() throws {
        let cases = [
            ("INITIALIZING", DeploymentState.initializing),
            ("initializing", DeploymentState.initializing),
            ("QUEUED", DeploymentState.queued),
            ("queued", DeploymentState.queued),
            ("BUILDING", DeploymentState.building),
            ("building", DeploymentState.building),
            ("READY", DeploymentState.ready),
            ("ready", DeploymentState.ready),
            ("ERROR", DeploymentState.error),
            ("error", DeploymentState.error),
            ("CANCELED", DeploymentState.canceled),
            ("canceled", DeploymentState.canceled),
            ("UNKNOWN", DeploymentState.unknown),
            ("FUTURE_STATE_XYZ", DeploymentState.unknown)
        ]
        
        for (raw, expected) in cases {
            let json = "\"\(raw)\""
            let decoded = try JSONDecoder().decode(DeploymentState.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(decoded, expected, "Failed for raw string: \(raw)")
            
            let fromHelper = DeploymentState(apiState: raw)
            XCTAssertEqual(fromHelper, expected, "Helper failed for: \(raw)")
        }
        
        XCTAssertEqual(DeploymentState(apiState: nil), .unknown)
    }
    
    func testDeploymentState_Classifications() {
        XCTAssertTrue(DeploymentState.ready.isLive)
        XCTAssertFalse(DeploymentState.building.isLive)
        
        XCTAssertTrue(DeploymentState.building.isInProgress)
        XCTAssertTrue(DeploymentState.queued.isInProgress)
        XCTAssertTrue(DeploymentState.initializing.isInProgress)
        XCTAssertTrue(DeploymentState.building.isActive)
        XCTAssertFalse(DeploymentState.ready.isInProgress)
        
        XCTAssertTrue(DeploymentState.error.isFailed)
        XCTAssertTrue(DeploymentState.canceled.isFailed)
        XCTAssertFalse(DeploymentState.ready.isFailed)
        
        XCTAssertTrue(DeploymentState.ready.isFinal)
        XCTAssertTrue(DeploymentState.error.isFinal)
        XCTAssertTrue(DeploymentState.canceled.isFinal)
        XCTAssertFalse(DeploymentState.building.isFinal)
    }
    
    func testDeploymentState_DisplayAndIcons() {
        XCTAssertEqual(DeploymentState.ready.displayName, "Ready")
        XCTAssertEqual(DeploymentState.ready.iconName, "checkmark.circle.fill")
        XCTAssertEqual(DeploymentState.ready.statusBadgeColorName, "systemGreen")
        
        XCTAssertEqual(DeploymentState.building.displayName, "Building")
        XCTAssertEqual(DeploymentState.building.iconName, "arrow.triangle.2.circlepath")
        XCTAssertEqual(DeploymentState.building.statusBadgeColorName, "systemBlue")
        
        XCTAssertEqual(DeploymentState.error.displayName, "Error")
        XCTAssertEqual(DeploymentState.error.iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(DeploymentState.error.statusBadgeColorName, "systemRed")
        
        XCTAssertEqual(DeploymentState.canceled.displayName, "Canceled")
        XCTAssertEqual(DeploymentState.canceled.iconName, "slash.circle.fill")
        XCTAssertEqual(DeploymentState.canceled.statusBadgeColorName, "systemGray")
    }
    
    // MARK: - DeploymentMeta Model Tests
    
    func testDeploymentMeta_CommitMessageFallbacks() {
        let ghMeta = DeploymentMeta(githubCommitMessage: "feat: add oauth")
        XCTAssertEqual(ghMeta.commitMessage, "feat: add oauth")
        
        let glMeta = DeploymentMeta(gitlabCommitMessage: "fix: gitlab pipeline")
        XCTAssertEqual(glMeta.commitMessage, "fix: gitlab pipeline")
        
        let bbMeta = DeploymentMeta(bitbucketCommitMessage: "chore: bitbucket merge")
        XCTAssertEqual(bbMeta.commitMessage, "chore: bitbucket merge")
    }
    
    func testDeploymentMeta_AuthorAndShortSha() {
        let meta = DeploymentMeta(
            githubCommitRef: "feat/pulse-ui",
            githubCommitAuthorName: "Michael Nashed",
            githubCommitAuthorLogin: "michaelnashed",
            githubCommitSha: "0123456789abcdef0123456789abcdef01234567"
        )
        
        XCTAssertEqual(meta.branchName, "feat/pulse-ui")
        XCTAssertEqual(meta.authorName, "Michael Nashed")
        XCTAssertEqual(meta.shortSha, "0123456")
        
        let loginOnlyMeta = DeploymentMeta(githubCommitAuthorLogin: "octocat")
        XCTAssertEqual(loginOnlyMeta.authorName, "octocat")
        
        let shortShaMeta = DeploymentMeta(githubCommitSha: "abc")
        XCTAssertEqual(shortShaMeta.shortSha, "abc")
    }
    
    // MARK: - Deployment Model Tests
    
    func testDeployment_ProductionVsPreviewClassification() {
        let prodTarget = Deployment(uid: "1", name: "app", url: "app.com", target: "production")
        XCTAssertTrue(prodTarget.isProduction)
        XCTAssertFalse(prodTarget.isPreview)
        
        let previewTarget = Deployment(uid: "2", name: "app", url: "app.com", target: "preview")
        XCTAssertFalse(previewTarget.isProduction)
        XCTAssertTrue(previewTarget.isPreview)
        
        let mainBranch = Deployment(
            uid: "3",
            name: "app",
            url: "app.com",
            target: nil,
            meta: DeploymentMeta(githubCommitRef: "main")
        )
        XCTAssertTrue(mainBranch.isProduction)
        
        let featureBranch = Deployment(
            uid: "4",
            name: "app",
            url: "app.com",
            target: nil,
            meta: DeploymentMeta(githubCommitRef: "feat/something")
        )
        XCTAssertFalse(featureBranch.isProduction)
    }
    
    func testDeployment_DurationFormatting() {
        // 1. Ready deployment with 45s build duration
        let ready45s = Deployment(
            uid: "dpl_1",
            name: "app",
            url: "app.com",
            state: "READY",
            created: 1000000,
            ready: 1045000
        )
        XCTAssertEqual(ready45s.durationFormatted, "45s")
        
        // 2. Ready deployment with 1m 20s build duration
        let ready80s = Deployment(
            uid: "dpl_2",
            name: "app",
            url: "app.com",
            state: "READY",
            created: 1000000,
            ready: 1080000
        )
        XCTAssertEqual(ready80s.durationFormatted, "1m 20s")
        
        // 3. In-progress building deployment
        let building = Deployment(
            uid: "dpl_3",
            name: "app",
            url: "app.com",
            state: "BUILDING",
            created: Int64(Date().timeIntervalSince1970 * 1000) - 15000,
            buildingAt: Int64(Date().timeIntervalSince1970 * 1000) - 15000
        )
        XCTAssertNotNil(building.durationFormatted)
    }
    
    func testDeployment_RelativeCreatedTime() {
        let deployment = Deployment(
            uid: "dpl_recent",
            name: "app",
            url: "app.com",
            created: Int64(Date().timeIntervalSince1970 * 1000) - 120000 // 2 minutes ago
        )
        XCTAssertFalse(deployment.relativeCreatedTime.isEmpty)
    }
    
    // MARK: - DeploymentsResponse Envelope Tests
    
    func testDeploymentsResponse_Decoding() throws {
        let json = """
        {
            "pagination": {
                "count": 2,
                "next": 1725190000000,
                "prev": 1725180000000
            },
            "deployments": [
                {
                    "uid": "dpl_01",
                    "name": "pulse-storefront",
                    "url": "pulse-storefront.vercel.app",
                    "created": 1725190000000,
                    "ready": 1725190045000,
                    "state": "READY",
                    "target": "production",
                    "inspectorUrl": "https://vercel.com/acme/pulse-storefront/dpl_01",
                    "creator": { "username": "michael" },
                    "meta": {
                        "githubCommitMessage": "fix: resolve navigation regression",
                        "githubCommitRef": "main",
                        "githubCommitAuthorName": "Michael",
                        "githubCommitSha": "1234567890abcdef"
                    }
                }
            ]
        }
        """
        
        let response = try JSONDecoder().decode(DeploymentsResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.deployments.count, 1)
        XCTAssertEqual(response.pagination?.count, 2)
        XCTAssertEqual(response.pagination?.next, 1725190000000)
        XCTAssertEqual(response.pagination?.prev, 1725180000000)
        
        let first = response.deployments[0]
        XCTAssertEqual(first.uid, "dpl_01")
        XCTAssertEqual(first.name, "pulse-storefront")
        XCTAssertEqual(first.status, .ready)
        XCTAssertTrue(first.isProduction)
        XCTAssertEqual(first.durationFormatted, "45s")
        XCTAssertEqual(first.meta?.shortSha, "1234567")
    }
}
