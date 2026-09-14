import XCTest
import CryptoKit

final class OAuthServiceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }
    
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    func testPKCEVerifierGenerationEntropyAndLength() {
        let verifierDefault = TestPKCEHelper.generateCodeVerifier()
        XCTAssertGreaterThanOrEqual(verifierDefault.count, 43)
        XCTAssertLessThanOrEqual(verifierDefault.count, 128)
        
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        XCTAssertTrue(verifierDefault.unicodeScalars.allSatisfy { allowedCharacters.contains($0) })
        
        let verifierCustomMin = TestPKCEHelper.generateCodeVerifier(length: 43)
        XCTAssertEqual(verifierCustomMin.count, 43)
        
        let verifierCustomMax = TestPKCEHelper.generateCodeVerifier(length: 128)
        XCTAssertEqual(verifierCustomMax.count, 128)
        
        // Clamping check
        let verifierClampedLow = TestPKCEHelper.generateCodeVerifier(length: 10)
        XCTAssertEqual(verifierClampedLow.count, 43)
        
        let verifierClampedHigh = TestPKCEHelper.generateCodeVerifier(length: 200)
        XCTAssertEqual(verifierClampedHigh.count, 128)
    }
    
    func testPKCEChallengeS256Computation() {
        let testVerifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let challenge = TestPKCEHelper.generateCodeChallenge(from: testVerifier)
        
        XCTAssertFalse(challenge.isEmpty)
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("/"))
        XCTAssertFalse(challenge.contains("="))
        
        // Deterministic check for RFC 7636 Appendix B example
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        let computed = TestPKCEHelper.generateCodeChallenge(from: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        XCTAssertEqual(computed, expectedChallenge)
        
        // Computed should match standard base64url SHA256 of the verifier
        let verifierData = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk".data(using: .ascii)!
        let hash = SHA256.hash(data: verifierData)
        let manualBase64Url = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        XCTAssertEqual(computed, manualBase64Url)
    }
    
    func testOAuthTokenDecodingFromJSON() throws {
        let json = TestFixtures.oauthTokenExchangeJSON
        let data = json.data(using: .utf8)!
        
        struct ExchangeResponse: Decodable {
            let tokenType: String
            let accessToken: String
            let refreshToken: String?
            let expiresIn: Int?
            let scope: String?
            let teamId: String?
            let userId: String?
            
            enum CodingKeys: String, CodingKey {
                case tokenType = "token_type"
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
                case scope
                case teamId = "team_id"
                case userId = "user_id"
            }
        }
        
        let decoded = try JSONDecoder().decode(ExchangeResponse.self, from: data)
        XCTAssertEqual(decoded.tokenType, "Bearer")
        XCTAssertEqual(decoded.accessToken, "vcp_tok_test_abc123456789xyz")
        XCTAssertEqual(decoded.refreshToken, "vcp_ref_test_987654321zyx")
        XCTAssertEqual(decoded.expiresIn, 86400)
        XCTAssertEqual(decoded.teamId, "team_alpha_prod_001")
        XCTAssertEqual(decoded.userId, "usr_dev_johndoe_42")
    }
    
    func testOAuthTokenExpirationEvaluation() {
        let expiredToken = TestOAuthToken(
            accessToken: "expired_token",
            expiresIn: -100,
            expiresAt: Date().addingTimeInterval(-100)
        )
        XCTAssertTrue(expiredToken.isExpired)
        XCTAssertTrue(expiredToken.shouldRefresh)
        
        let soonExpiringToken = TestOAuthToken(
            accessToken: "soon_token",
            expiresIn: 30,
            expiresAt: Date().addingTimeInterval(30)
        )
        XCTAssertFalse(soonExpiringToken.isExpired)
        XCTAssertTrue(soonExpiringToken.shouldRefresh) // <= 60s
        
        let freshToken = TestOAuthToken(
            accessToken: "fresh_token",
            expiresIn: 86400,
            expiresAt: Date().addingTimeInterval(86400)
        )
        XCTAssertFalse(freshToken.isExpired)
        XCTAssertFalse(freshToken.shouldRefresh)
    }
    
    func testOAuthTokenRefreshExchangeViaMockURLProtocol() async throws {
        let session = MockURLProtocol.makeMockSession()
        MockURLProtocol.stub(
            endpoint: "/v2/oauth/access_token",
            jsonString: TestFixtures.oauthTokenRefreshJSON,
            statusCode: 200
        )
        
        var request = URLRequest(url: URL(string: "https://api.vercel.com/v2/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=test_client&grant_type=refresh_token&refresh_token=vcp_ref_test_987654321zyx"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(jsonObject?["access_token"] as? String, "vcp_tok_refreshed_new_999888777")
        XCTAssertEqual(jsonObject?["refresh_token"] as? String, "vcp_ref_rotated_fresh_111222333")
        
        XCTAssertEqual(MockURLProtocol.recordedRequests.count, 1)
        XCTAssertEqual(MockURLProtocol.recordedRequests.first?.httpMethod, "POST")
    }
}
