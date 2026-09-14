import XCTest

final class KeychainManagerTests: XCTestCase {
    
    var mockKeychain: MockKeychainManager!
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainManager()
    }
    
    override func tearDown() {
        mockKeychain.reset()
        mockKeychain = nil
        super.tearDown()
    }
    
    func testStringSaveAndGet() throws {
        let key = "test_key_1"
        let secret = "super_secret_value_123"
        
        try mockKeychain.save(key: key, string: secret)
        XCTAssertEqual(mockKeychain.saveCallCount, 1)
        
        let retrieved = mockKeychain.getString(key: key)
        XCTAssertEqual(mockKeychain.getCallCount, 1)
        XCTAssertEqual(retrieved, secret)
    }
    
    func testDataSaveAndGet() throws {
        let key = "binary_key"
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        
        try mockKeychain.save(key: key, data: data)
        let retrieved = try mockKeychain.getData(key: key)
        XCTAssertEqual(retrieved, data)
    }
    
    func testDeleteKey() throws {
        let key = "ephemeral_key"
        try mockKeychain.save(key: key, string: "will_be_deleted")
        XCTAssertNotNil(mockKeychain.getString(key: key))
        
        try mockKeychain.delete(key: key)
        XCTAssertEqual(mockKeychain.deleteCallCount, 1)
        XCTAssertNil(mockKeychain.getString(key: key))
    }
    
    func testPurgeAllKeys() throws {
        try mockKeychain.save(key: "k1", string: "v1")
        try mockKeychain.save(key: "k2", string: "v2")
        try mockKeychain.save(key: "k3", string: "v3")
        XCTAssertEqual(mockKeychain.count, 3)
        
        try mockKeychain.purgeAll()
        XCTAssertEqual(mockKeychain.purgeCallCount, 1)
        XCTAssertEqual(mockKeychain.count, 0)
        XCTAssertNil(mockKeychain.getString(key: "k1"))
        XCTAssertNil(mockKeychain.getString(key: "k2"))
        XCTAssertNil(mockKeychain.getString(key: "k3"))
    }
    
    func testOAuthTokenSerializationAndRetrieval() throws {
        let token = TestOAuthToken(
            accessToken: "vcp_tok_abc",
            refreshToken: "vcp_ref_xyz",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "deployments",
            teamId: "team_123",
            userId: "user_456"
        )
        
        try mockKeychain.saveToken(token)
        let retrieved = mockKeychain.getToken()
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.accessToken, "vcp_tok_abc")
        XCTAssertEqual(retrieved?.refreshToken, "vcp_ref_xyz")
        XCTAssertEqual(retrieved?.tokenType, "Bearer")
        XCTAssertEqual(retrieved?.teamId, "team_123")
        XCTAssertEqual(retrieved?.userId, "user_456")
    }
    
    func testKeychainSimulatedErrorHandling() {
        mockKeychain.shouldFailNextSave = true
        XCTAssertThrowsError(try mockKeychain.save(key: "err_key", string: "value")) { error in
            XCTAssertEqual(error as? MockKeychainManager.MockKeychainError, .simulatedFailure)
        }
        
        mockKeychain.shouldFailNextGet = true
        XCTAssertThrowsError(try mockKeychain.getData(key: "err_key")) { error in
            XCTAssertEqual(error as? MockKeychainManager.MockKeychainError, .simulatedFailure)
        }
        
        mockKeychain.shouldFailNextDelete = true
        XCTAssertThrowsError(try mockKeychain.delete(key: "err_key")) { error in
            XCTAssertEqual(error as? MockKeychainManager.MockKeychainError, .simulatedFailure)
        }
    }
}
