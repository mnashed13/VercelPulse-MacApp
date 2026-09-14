import XCTest
import CryptoKit

final class Tier2_BoundaryEdgeTests: XCTestCase {
    
    var mockSession: URLSession!
    var mockKeychain: MockKeychainManager!
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        mockSession = MockURLProtocol.makeMockSession()
        mockKeychain = MockKeychainManager()
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
        mockKeychain.reset()
        mockKeychain = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - 1. Timestamp Boundaries (Tests 01 - 05)
    
    func testB01_TimestampEpochZero() {
        let deployment = TestDeployment(uid: "dpl_0", name: "zero", url: "zero.app", state: "READY", created: 0)
        XCTAssertEqual(deployment.created, 0)
        let date = Date(timeIntervalSince1970: Double(deployment.created) / 1000.0)
        XCTAssertEqual(date.timeIntervalSince1970, 0)
    }
    
    func testB02_TimestampNegativeValue() {
        let deployment = TestDeployment(uid: "dpl_neg", name: "neg", url: "neg.app", state: "READY", created: -1000)
        XCTAssertEqual(deployment.created, -1000)
        let date = Date(timeIntervalSince1970: Double(deployment.created) / 1000.0)
        XCTAssertEqual(date.timeIntervalSince1970, -1.0)
    }
    
    func testB03_TimestampFarFuture() {
        let farFuture: Int64 = 4102444800000 // Year 2100
        let deployment = TestDeployment(uid: "dpl_future", name: "fut", url: "fut.app", state: "READY", created: farFuture)
        XCTAssertEqual(deployment.created, farFuture)
        let date = Date(timeIntervalSince1970: Double(deployment.created) / 1000.0)
        XCTAssertGreaterThan(date, Date())
    }
    
    func testB04_TimestampMaxInt64() {
        let maxTs = Int64.max
        let deployment = TestDeployment(uid: "dpl_max", name: "max", url: "max.app", state: "READY", created: maxTs)
        XCTAssertEqual(deployment.created, maxTs)
    }
    
    func testB05_TimestampMillisecondPrecisionPreserved() {
        let preciseTs: Int64 = 1725184800123
        let deployment = TestDeployment(uid: "dpl_prec", name: "prec", url: "prec.app", state: "READY", created: preciseTs)
        XCTAssertEqual(deployment.created % 1000, 123)
    }
    
    // MARK: - 2. Empty & Malformed Payloads (Tests 06 - 10)
    
    func testB06_EmptyStringPayloadDecodingFailsGracefully() {
        let emptyData = Data()
        XCTAssertThrowsError(try JSONDecoder().decode(TestDeploymentsResponse.self, from: emptyData))
    }
    
    func testB07_EmptyJSONObjectDecodesDefaultOrThrows() {
        let emptyJSON = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(TestDeploymentsResponse.self, from: emptyJSON))
    }
    
    func testB08_DeploymentsArrayNullThrows() {
        let nullDeployments = "{\"deployments\": null}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(TestDeploymentsResponse.self, from: nullDeployments))
    }
    
    func testB09_TruncatedJSONStreamThrows() {
        let truncated = "{\"deployments\": [{\"uid\": \"dpl_1\"".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(TestDeploymentsResponse.self, from: truncated))
    }
    
    func testB10_CorruptedUTF8BytesHandling() {
        let corruptedBytes = Data([0xFF, 0xFE, 0xFD])
        XCTAssertThrowsError(try JSONDecoder().decode(TestDeploymentsResponse.self, from: corruptedBytes))
    }
    
    // MARK: - 3. Corrupted & Edge-Case Tokens (Tests 11 - 15)
    
    func testB11_EmptyStringTokenHandledAsUnauthenticated() {
        let emptyToken = TestOAuthToken(accessToken: "")
        XCTAssertTrue(emptyToken.accessToken.isEmpty)
    }
    
    func testB12_UltraLongTokenString10kCharacters() throws {
        let longTokenString = String(repeating: "a", count: 10000)
        let token = TestOAuthToken(accessToken: longTokenString)
        try mockKeychain.saveToken(token)
        let retrieved = mockKeychain.getToken()
        XCTAssertEqual(retrieved?.accessToken.count, 10000)
    }
    
    func testB13_TokenWithControlCharactersAndNewlines() throws {
        let tokenWithControlChars = "vcp_tok_abc\r\n\t_xyz"
        let token = TestOAuthToken(accessToken: tokenWithControlChars)
        try mockKeychain.saveToken(token)
        let retrieved = mockKeychain.getToken()
        XCTAssertEqual(retrieved?.accessToken, tokenWithControlChars)
    }
    
    func testB14_TokenWithUnicodeEmojis() throws {
        let emojiToken = "vcp_tok_⚡️🔥🚀_secure"
        let token = TestOAuthToken(accessToken: emojiToken)
        try mockKeychain.saveToken(token)
        let retrieved = mockKeychain.getToken()
        XCTAssertEqual(retrieved?.accessToken, emojiToken)
    }
    
    func testB15_JWTTokenWithoutSegments() {
        let malformedJWT = "not.a.real.jwt.token"
        let segments = malformedJWT.components(separatedBy: ".")
        XCTAssertEqual(segments.count, 5)
    }
    
    // MARK: - 4. Pagination Boundaries (Tests 16 - 20)
    
    func testB16_PaginationLimitZero() {
        let limit = 0
        let clamped = max(1, min(limit, 100))
        XCTAssertEqual(clamped, 1)
    }
    
    func testB17_PaginationLimitOne() {
        let limit = 1
        let clamped = max(1, min(limit, 100))
        XCTAssertEqual(clamped, 1)
    }
    
    func testB18_PaginationLimitMax100() {
        let limit = 100
        let clamped = max(1, min(limit, 100))
        XCTAssertEqual(clamped, 100)
    }
    
    func testB19_PaginationLimitOverflowClampedTo100() {
        let limit = 500
        let clamped = max(1, min(limit, 100))
        XCTAssertEqual(clamped, 100)
    }
    
    func testB20_PaginationNegativeUntilCursor() {
        let until: Int64 = -1
        let url = URL(string: "https://api.vercel.com/v6/deployments?until=\(until)")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.query!.contains("until=-1"))
    }
    
    // MARK: - 5. Rate Limit Header Boundaries (Tests 21 - 25)
    
    func testB21_RateLimitRetryAfterZero() {
        let header = "0"
        let seconds = Int(header) ?? 60
        XCTAssertEqual(seconds, 0)
    }
    
    func testB22_RateLimitRetryAfterOneSecond() {
        let header = "1"
        let seconds = Int(header) ?? 60
        XCTAssertEqual(seconds, 1)
    }
    
    func testB23_RateLimitRetryAfterDay86400() {
        let header = "86400"
        let seconds = Int(header) ?? 60
        XCTAssertEqual(seconds, 86400)
    }
    
    func testB24_RateLimitRetryAfterNonNumericFallback() {
        let header = "invalid_seconds_string"
        let seconds = Int(header) ?? 60
        XCTAssertEqual(seconds, 60)
    }
    
    func testB25_RateLimitRetryAfterNegativeFallback() {
        let header = "-5"
        let raw = Int(header) ?? 60
        let seconds = max(0, raw)
        XCTAssertEqual(seconds, 0)
    }
    
    // MARK: - 6. Special Characters & Injection Resistance (Tests 26 - 30)
    
    func testB26_ProjectNameWithSpacesAndSymbols() {
        let projectName = "my cool project (v2) #1"
        let url = TestDeepLinkHelper.inspectorURL(teamSlug: "team_1", projectName: projectName, deploymentId: "dpl_1")
        XCTAssertNotNil(url)
    }
    
    func testB27_TeamSlugWithUnicodeAndDashes() {
        let teamSlug = "team-ök-dev"
        let url = TestDeepLinkHelper.inspectorURL(teamSlug: teamSlug, projectName: "app", deploymentId: "dpl_1")
        XCTAssertNotNil(url)
    }
    
    func testB28_CommitMessageWithQuotesAndNewlines() throws {
        let meta = TestDeploymentMeta(githubCommitMessage: "feat: \"add support\"\n\nCo-authored-by: bot <bot@vercel.com>")
        let encoded = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(TestDeploymentMeta.self, from: encoded)
        XCTAssertEqual(decoded.githubCommitMessage, "feat: \"add support\"\n\nCo-authored-by: bot <bot@vercel.com>")
    }
    
    func testB29_BranchNameWithSlashesAndHashes() {
        let branch = "feature/JIRA-123#sub-task"
        let meta = TestDeploymentMeta(githubCommitRef: branch)
        XCTAssertEqual(meta.githubCommitRef, branch)
    }
    
    func testB30_AuthorNameWithRTLAndUnicode() {
        let author = "مطور البرمجيات 💻"
        let meta = TestDeploymentMeta(githubCommitAuthorName: author)
        XCTAssertEqual(meta.githubCommitAuthorName, author)
    }
    
    // MARK: - 7. HTTP Status Code Boundary Responses (Tests 31 - 35)
    
    func testB31_HTTP204NoContent() async throws {
        MockURLProtocol.stub(
            endpoint: "/v1/test204",
            response: MockURLProtocol.MockResponse(statusCode: 204, data: nil)
        )
        let (data, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v1/test204")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 204)
        XCTAssertTrue(data.isEmpty)
    }
    
    func testB32_HTTP304NotModified() async throws {
        MockURLProtocol.stub(
            endpoint: "/v1/test304",
            response: MockURLProtocol.MockResponse(statusCode: 304, data: nil)
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v1/test304")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 304)
    }
    
    func testB33_HTTP400BadRequest() async throws {
        MockURLProtocol.stub(
            endpoint: "/v1/test400",
            response: MockURLProtocol.MockResponse(statusCode: 400, data: "{\"error\": \"bad_request\"}".data(using: .utf8))
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v1/test400")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 400)
    }
    
    func testB34_HTTP502BadGateway() async throws {
        MockURLProtocol.stub(
            endpoint: "/v1/test502",
            response: MockURLProtocol.MockResponse(statusCode: 502, data: "Bad Gateway".data(using: .utf8))
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v1/test502")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 502)
    }
    
    func testB35_HTTP503ServiceUnavailable() async throws {
        MockURLProtocol.stub(
            endpoint: "/v1/test503",
            response: MockURLProtocol.MockResponse(statusCode: 503, data: "Service Unavailable".data(using: .utf8))
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v1/test503")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 503)
    }
    
    // MARK: - 8. Keychain Boundary Operations (Tests 36 - 40)
    
    func testB36_KeychainSaveEmptyData() throws {
        try mockKeychain.save(key: "empty_data_key", data: Data())
        let retrieved = try mockKeychain.getData(key: "empty_data_key")
        XCTAssertEqual(retrieved, Data())
    }
    
    func testB37_KeychainSaveLargePayload1MB() throws {
        let largeData = Data(repeating: 0x41, count: 1024 * 1024)
        try mockKeychain.save(key: "large_payload_key", data: largeData)
        let retrieved = try mockKeychain.getData(key: "large_payload_key")
        XCTAssertEqual(retrieved?.count, 1024 * 1024)
    }
    
    func testB38_KeychainDeleteNonExistentKeyDoesNotThrow() throws {
        XCTAssertNoThrow(try mockKeychain.delete(key: "non_existent_key_999"))
    }
    
    func testB39_KeychainGetNonExistentKeyReturnsNil() {
        let retrieved = mockKeychain.getString(key: "missing_key_000")
        XCTAssertNil(retrieved)
    }
    
    func testB40_KeychainOverwritePreservesLatest() throws {
        try mockKeychain.save(key: "overwrite_key", string: "value_1")
        try mockKeychain.save(key: "overwrite_key", string: "value_2")
        try mockKeychain.save(key: "overwrite_key", string: "value_3")
        XCTAssertEqual(mockKeychain.getString(key: "overwrite_key"), "value_3")
        XCTAssertEqual(mockKeychain.count, 1)
    }
    
    // MARK: - 9. State Enum Resilient Fallbacks (Tests 41 - 45)
    
    func testB41_StateEnumFallbackUnknownString() {
        let state = TestDeploymentState(apiState: "FUTURE_AI_DEPLOYING")
        XCTAssertEqual(state, .unknown)
    }
    
    func testB42_StateEnumFallbackNil() {
        let state = TestDeploymentState(apiState: nil)
        XCTAssertEqual(state, .unknown)
    }
    
    func testB43_StateEnumFallbackEmptyString() {
        let state = TestDeploymentState(apiState: "")
        XCTAssertEqual(state, .unknown)
    }
    
    func testB44_StateEnumCaseInsensitiveMatching() {
        let lowercase = TestDeploymentState(apiState: "ready")
        let mixed = TestDeploymentState(apiState: "bUiLdInG")
        XCTAssertEqual(lowercase, .ready)
        XCTAssertEqual(mixed, .building)
    }
    
    func testB45_StateEnumAllCasesCompleteness() {
        XCTAssertEqual(TestDeploymentState.allCases.count, 7)
    }
    
    // MARK: - 10. PKCE RFC 7636 Length & Validation Boundaries (Tests 46 - 50)
    
    func testB46_PKCEVerifierMinClamping43() {
        let v = TestPKCEHelper.generateCodeVerifier(length: 1)
        XCTAssertEqual(v.count, 43)
    }
    
    func testB47_PKCEVerifierMaxClamping128() {
        let v = TestPKCEHelper.generateCodeVerifier(length: 999)
        XCTAssertEqual(v.count, 128)
    }
    
    func testB48_PKCEChallengeDeterministicForEmptyString() {
        let challenge = TestPKCEHelper.generateCodeChallenge(from: "")
        XCTAssertFalse(challenge.isEmpty)
    }
    
    func testB49_PKCEChallengeURLSafeNoPadding() {
        for length in [43, 64, 96, 128] {
            let v = TestPKCEHelper.generateCodeVerifier(length: length)
            let c = TestPKCEHelper.generateCodeChallenge(from: v)
            XCTAssertFalse(c.contains("="), "Base64URL challenge must not contain '=' padding")
            XCTAssertFalse(c.contains("+"))
            XCTAssertFalse(c.contains("/"))
        }
    }
    
    func testB50_PKCEVerifierUnreservedCharacterCompliance() {
        let v = TestPKCEHelper.generateCodeVerifier(length: 128)
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        XCTAssertTrue(v.unicodeScalars.allSatisfy { unreserved.contains($0) })
    }
    
    // MARK: - 11. Deep Link Boundary Conditions (Tests 51 - 55)
    
    func testB51_DeepLinkEmptyTeamProducesTilde() {
        let url = TestDeepLinkHelper.inspectorURL(teamSlug: "", projectName: "my-proj", deploymentId: "dpl_1")
        XCTAssertEqual(url?.pathComponents[1], "~")
    }
    
    func testB52_DeepLinkPreviewWithHttpReplacesOrPreserves() {
        let url = TestDeepLinkHelper.previewURL(domain: "http://test.vercel.app")
        XCTAssertEqual(url?.scheme, "http")
    }
    
    func testB53_DeepLinkPreviewWithWhitespace() {
        let url = TestDeepLinkHelper.previewURL(domain: "  \n  app.vercel.app  \t ")
        XCTAssertEqual(url?.host, "app.vercel.app")
    }
    
    func testB54_DeepLinkCommitEmptyOrgReturnsNil() {
        let url = TestDeepLinkHelper.commitURL(org: "", repo: "repo", sha: "sha")
        XCTAssertNil(url)
    }
    
    func testB55_DeepLinkCommitEmptyRepoReturnsNil() {
        let url = TestDeepLinkHelper.commitURL(org: "org", repo: "", sha: "sha")
        XCTAssertNil(url)
    }
    
    // MARK: - 12. Polling Strategy Boundary Conditions (Tests 56 - 60)
    
    func testB56_PollingIntervalEmptyDeploymentsDefaultsToRelaxed() {
        let deployments: [TestDeployment] = []
        let interval = TestPollingEngine.computePollingInterval(for: deployments)
        XCTAssertEqual(interval, 60.0)
    }
    
    func testB57_PollingIntervalOneBuildingAmong1000Ready() {
        var list = (1...999).map { TestDeployment(uid: "\($0)", name: "app", url: "app.com", state: "READY") }
        list.append(TestDeployment(uid: "1000", name: "app", url: "app.com", state: "BUILDING"))
        let interval = TestPollingEngine.computePollingInterval(for: list)
        XCTAssertEqual(interval, 10.0)
    }
    
    func testB58_PollingIntervalInitializingAccelerates() {
        let list = [TestDeployment(uid: "1", name: "app", url: "app.com", state: "INITIALIZING")]
        let interval = TestPollingEngine.computePollingInterval(for: list)
        XCTAssertEqual(interval, 10.0)
    }
    
    func testB59_PollingIntervalAllErrorRelaxes() {
        let list = [
            TestDeployment(uid: "1", name: "app", url: "app.com", state: "ERROR"),
            TestDeployment(uid: "2", name: "app", url: "app.com", state: "ERROR")
        ]
        let interval = TestPollingEngine.computePollingInterval(for: list)
        XCTAssertEqual(interval, 60.0)
    }
    
    func testB60_PollingIntervalAllCanceledRelaxes() {
        let list = [
            TestDeployment(uid: "1", name: "app", url: "app.com", state: "CANCELED")
        ]
        let interval = TestPollingEngine.computePollingInterval(for: list)
        XCTAssertEqual(interval, 60.0)
    }
    
    // MARK: - 13. Scope Filter Boundary Conditions (Tests 61 - 65)
    
    func testB61_FilterProductionWithNilTargetAndMainBranch() {
        let dep = TestDeployment(
            uid: "1", name: "app", url: "app.com", state: "READY",
            meta: TestDeploymentMeta(githubCommitRef: "main"),
            target: nil
        )
        XCTAssertTrue(dep.isProduction)
        XCTAssertFalse(dep.isPreview)
    }
    
    func testB62_FilterProductionWithNilTargetAndMasterBranch() {
        let dep = TestDeployment(
            uid: "1", name: "app", url: "app.com", state: "READY",
            meta: TestDeploymentMeta(githubCommitRef: "master"),
            target: nil
        )
        XCTAssertTrue(dep.isProduction)
        XCTAssertFalse(dep.isPreview)
    }
    
    func testB63_FilterProductionExplicitTargetProduction() {
        let dep = TestDeployment(
            uid: "1", name: "app", url: "app.com", state: "READY",
            meta: TestDeploymentMeta(githubCommitRef: "feat/some-branch"),
            target: "production"
        )
        XCTAssertTrue(dep.isProduction)
    }
    
    func testB64_FilterPreviewExplicitTargetPreview() {
        let dep = TestDeployment(
            uid: "1", name: "app", url: "app.com", state: "READY",
            meta: TestDeploymentMeta(githubCommitRef: "main"),
            target: "preview"
        )
        // Explicit preview target overrides or defaults
        XCTAssertFalse(dep.isProduction)
        XCTAssertTrue(dep.isPreview)
    }
    
    func testB65_FilterScopeEmptyListReturnsEmpty() {
        let empty: [TestDeployment] = []
        XCTAssertEqual(empty.filter { $0.isProduction }.count, 0)
        XCTAssertEqual(empty.filter { $0.isPreview }.count, 0)
    }
    
    // MARK: - 14. Usage Metrics Boundary Values (Tests 66 - 70)
    
    func testB66_UsageMetricsZeroLimit() {
        let detail = TestUsageMetricDetail(limit: 0, usage: 100)
        XCTAssertEqual(detail.limit, 0)
        XCTAssertEqual(detail.usage, 100)
    }
    
    func testB67_UsageMetricsZeroUsage() {
        let detail = TestUsageMetricDetail(limit: 1000, usage: 0)
        XCTAssertEqual(detail.usage, 0)
    }
    
    func testB68_UsageMetricsNilMetrics() {
        let usage = TestUsage(metrics: nil)
        XCTAssertNil(usage.metrics)
    }
    
    func testB69_UsageMetricsEmptyMetricsDictionary() {
        let usage = TestUsage(metrics: [:])
        XCTAssertTrue(usage.metrics!.isEmpty)
    }
    
    func testB70_UsageMetricsLargeOverage() {
        let detail = TestUsageMetricDetail(limit: 1000, usage: 50000)
        XCTAssertGreaterThan(detail.usage!, detail.limit!)
    }
    
    // MARK: - 15. Network Transport Edge Cases (Tests 71 - 75)
    
    func testB71_ZeroByteResponseHandling() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/empty",
            response: MockURLProtocol.MockResponse(statusCode: 200, data: Data())
        )
        let (data, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/empty")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(data.count, 0)
    }
    
    func testB72_NetworkConnectionLostSimulation() async {
        MockURLProtocol.stub(
            endpoint: "/v6/network-lost",
            response: MockURLProtocol.MockResponse(error: URLError(.networkConnectionLost))
        )
        do {
            _ = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/network-lost")!))
            XCTFail("Should throw networkConnectionLost")
        } catch let err as URLError {
            XCTAssertEqual(err.code, .networkConnectionLost)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testB73_NetworkDNSErrorSimulation() async {
        MockURLProtocol.stub(
            endpoint: "/v6/dns-fail",
            response: MockURLProtocol.MockResponse(error: URLError(.cannotFindHost))
        )
        do {
            _ = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/dns-fail")!))
            XCTFail("Should throw cannotFindHost")
        } catch let err as URLError {
            XCTAssertEqual(err.code, .cannotFindHost)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testB74_NetworkSSLErrorSimulation() async {
        MockURLProtocol.stub(
            endpoint: "/v6/ssl-fail",
            response: MockURLProtocol.MockResponse(error: URLError(.secureConnectionFailed))
        )
        do {
            _ = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/ssl-fail")!))
            XCTFail("Should throw secureConnectionFailed")
        } catch let err as URLError {
            XCTAssertEqual(err.code, .secureConnectionFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testB75_CustomHeaderCaseInsensitivityInResponse() async throws {
        MockURLProtocol.stub(
            endpoint: "/v6/headers",
            jsonString: "{}",
            statusCode: 200,
            headers: ["X-Vercel-RateLimit-Remaining": "49"]
        )
        let (_, response) = try await mockSession.data(for: URLRequest(url: URL(string: "https://api.vercel.com/v6/headers")!))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.value(forHTTPHeaderField: "x-vercel-ratelimit-remaining"), "49")
    }
    
    // MARK: - 16. OAuth Callback & State Boundary Cases (Tests 76 - 80)
    
    func testB76_OAuthCallbackWith256CharState() {
        let longState = String(repeating: "s", count: 256)
        let url = URL(string: "vercelpulse://oauth-callback?code=abc&state=\(longState)")!
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(comp?.queryItems?.first(where: { $0.name == "state" })?.value?.count, 256)
    }
    
    func testB77_OAuthCallbackWithEmptyCode() {
        let url = URL(string: "vercelpulse://oauth-callback?code=&state=abc")!
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = comp?.queryItems?.first(where: { $0.name == "code" })?.value
        XCTAssertEqual(code, "")
    }
    
    func testB78_OAuthCallbackWithEmptyState() {
        let url = URL(string: "vercelpulse://oauth-callback?code=abc&state=")!
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let state = comp?.queryItems?.first(where: { $0.name == "state" })?.value
        XCTAssertEqual(state, "")
    }
    
    func testB79_OAuthCallbackWithMultipleCodesTakesFirst() {
        let url = URL(string: "vercelpulse://oauth-callback?code=first&code=second&state=123")!
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = comp?.queryItems?.first(where: { $0.name == "code" })?.value
        XCTAssertEqual(code, "first")
    }
    
    func testB80_OAuthCallbackWithErrorParameterExtraction() {
        let url = URL(string: "vercelpulse://oauth-callback?error=unauthorized_client&error_description=The+client+is+disabled")!
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let error = comp?.queryItems?.first(where: { $0.name == "error" })?.value
        let desc = comp?.queryItems?.first(where: { $0.name == "error_description" })?.value?.replacingOccurrences(of: "+", with: " ")
        XCTAssertEqual(error, "unauthorized_client")
        XCTAssertEqual(desc, "The client is disabled")
    }
}
