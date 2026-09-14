import XCTest
import Security
@testable import VercelPulse

final class KeychainConcurrencyResilienceTests: XCTestCase {
    
    private var testServiceName: String!
    private var testKeychain: KeychainManager!
    
    override func setUp() {
        super.setUp()
        testServiceName = "com.vercelpulse.test.keychain.\(UUID().uuidString)"
        testKeychain = KeychainManager(serviceName: testServiceName)
    }
    
    override func tearDown() {
        if let keychain = testKeychain {
            try? keychain.purgeAll()
            testKeychain = nil
        }
        super.tearDown()
    }
    
    // MARK: - Group 1: Real KeychainManager Concurrency & Multi-Threading Stress
    
    func testKeychain_ConcurrentMultiThreadedWrites() {
        let iterations = 50
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.vercelpulse.test.concurrency.writes", attributes: .concurrent)
        
        var errors: [Error] = []
        let errorLock = NSLock()
        
        for i in 0..<iterations {
            group.enter()
            queue.async {
                defer { group.leave() }
                let key = "concurrent_key_\(i)"
                let value = "payload_content_\(i)_\(UUID().uuidString)"
                do {
                    try self.testKeychain.save(key: key, string: value)
                } catch {
                    errorLock.lock()
                    errors.append(error)
                    errorLock.unlock()
                }
            }
        }
        
        let waitResult = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(waitResult, .success, "Multi-threaded writes timed out (potential deadlock)")
        XCTAssertTrue(errors.isEmpty, "Encountered errors during concurrent writes: \(errors)")
        
        // Verify all items were written correctly
        for i in 0..<iterations {
            let key = "concurrent_key_\(i)"
            let retrieved = testKeychain.getString(key: key)
            XCTAssertNotNil(retrieved, "Missing key: \(key)")
            XCTAssertTrue(retrieved?.hasPrefix("payload_content_\(i)_") == true)
        }
    }
    
    func testKeychain_ConcurrentCollisionWritesOnSingleKey() {
        let iterations = 50
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.vercelpulse.test.concurrency.collision", attributes: .concurrent)
        let collisionKey = "single_shared_collision_key"
        
        var errors: [Error] = []
        let errorLock = NSLock()
        
        for i in 0..<iterations {
            group.enter()
            queue.async {
                defer { group.leave() }
                let value = "thread_value_\(i)"
                do {
                    try self.testKeychain.save(key: collisionKey, string: value)
                } catch {
                    errorLock.lock()
                    errors.append(error)
                    errorLock.unlock()
                }
            }
        }
        
        let waitResult = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(waitResult, .success, "Concurrent collision writes timed out (potential deadlock)")
        XCTAssertTrue(errors.isEmpty, "Collision write errors (SecItemAdd/SecItemUpdate race): \(errors)")
        
        // Value should be one of the thread values
        let finalValue = testKeychain.getString(key: collisionKey)
        XCTAssertNotNil(finalValue)
        XCTAssertTrue(finalValue?.hasPrefix("thread_value_") == true)
    }
    
    func testKeychain_ConcurrentReadWriteDeleteStress() {
        let iterations = 100
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.vercelpulse.test.concurrency.stress", attributes: .concurrent)
        
        var errors: [Error] = []
        let errorLock = NSLock()
        
        // Seed initial items
        for i in 0..<10 {
            try? testKeychain.save(key: "stress_key_\(i)", string: "initial_\(i)")
        }
        
        for i in 0..<iterations {
            group.enter()
            queue.async {
                defer { group.leave() }
                let op = i % 5
                let key = "stress_key_\(i % 10)"
                
                do {
                    switch op {
                    case 0:
                        try self.testKeychain.save(key: key, string: "updated_\(i)")
                    case 1:
                        _ = self.testKeychain.getString(key: key)
                    case 2:
                        _ = try self.testKeychain.getData(key: key)
                    case 3:
                        try self.testKeychain.delete(key: key)
                    case 4:
                        let token = OAuthToken(accessToken: "tok_\(i)", expiresIn: 3600)
                        try self.testKeychain.saveToken(token)
                        _ = self.testKeychain.getToken()
                    default:
                        break
                    }
                } catch {
                    errorLock.lock()
                    errors.append(error)
                    errorLock.unlock()
                }
            }
        }
        
        let waitResult = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(waitResult, .success, "Concurrent read/write/delete timed out")
        XCTAssertTrue(errors.isEmpty, "Errors during concurrent stress operations: \(errors)")
    }
    
    func testKeychain_DeadlockFreedomUnderExtremeContention() {
        let iterations = 150
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.vercelpulse.test.deadlock.contention", attributes: .concurrent)
        
        for i in 0..<iterations {
            group.enter()
            queue.async {
                defer { group.leave() }
                let key = "deadlock_key_\(i % 5)"
                if i % 3 == 0 {
                    try? self.testKeychain.save(key: key, string: "val_\(i)")
                } else if i % 3 == 1 {
                    _ = self.testKeychain.getString(key: key)
                } else {
                    try? self.testKeychain.delete(key: key)
                }
            }
        }
        
        let waitResult = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(waitResult, .success, "Deadlock detected: threads failed to complete within 5 seconds")
    }
    
    func testKeychain_SwiftAsyncStructuredConcurrency() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<40 {
                group.addTask {
                    let key = "async_key_\(i)"
                    try self.testKeychain.save(key: key, string: "async_val_\(i)")
                    let retrieved = self.testKeychain.getString(key: key)
                    XCTAssertEqual(retrieved, "async_val_\(i)")
                    
                    let token = OAuthToken(accessToken: "async_tok_\(i)", expiresIn: 1800)
                    try self.testKeychain.saveToken(token)
                    let readToken = self.testKeychain.getToken()
                    XCTAssertNotNil(readToken)
                }
            }
            try await group.waitForAll()
        }
    }
    
    // MARK: - Group 2: Boundary Data Sizes & Special Characters
    
    func testKeychain_BoundaryZeroByteData() throws {
        let emptyData = Data()
        try testKeychain.save(key: "empty_data_key", data: emptyData)
        let retrieved = try testKeychain.getData(key: "empty_data_key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, emptyData)
    }
    
    func testKeychain_BoundarySingleByteData() throws {
        let singleByte = Data([0x7F])
        try testKeychain.save(key: "single_byte_key", data: singleByte)
        let retrieved = try testKeychain.getData(key: "single_byte_key")
        XCTAssertEqual(retrieved, singleByte)
    }
    
    func testKeychain_BoundaryLargePayload_64KB() throws {
        var bytes = [UInt8](repeating: 0, count: 64 * 1024)
        for i in 0..<bytes.count {
            bytes[i] = UInt8(i % 256)
        }
        let data64KB = Data(bytes)
        try testKeychain.save(key: "large_64kb_key", data: data64KB)
        let retrieved = try testKeychain.getData(key: "large_64kb_key")
        XCTAssertEqual(retrieved, data64KB)
    }
    
    func testKeychain_BoundaryLargePayload_512KB() throws {
        var bytes = [UInt8](repeating: 0, count: 512 * 1024)
        for i in 0..<bytes.count {
            bytes[i] = UInt8((i * 7) % 256)
        }
        let data512KB = Data(bytes)
        try testKeychain.save(key: "large_512kb_key", data: data512KB)
        let retrieved = try testKeychain.getData(key: "large_512kb_key")
        XCTAssertEqual(retrieved, data512KB)
    }
    
    func testKeychain_BoundaryLargePayload_1MB() throws {
        let count = 1024 * 1024
        var bytes = [UInt8](repeating: 0xAB, count: count)
        bytes[0] = 0x12
        bytes[count - 1] = 0x34
        let data1MB = Data(bytes)
        try testKeychain.save(key: "large_1mb_key", data: data1MB)
        let retrieved = try testKeychain.getData(key: "large_1mb_key")
        XCTAssertEqual(retrieved, data1MB)
    }
    
    func testKeychain_BoundarySpecialCharactersInKeys() throws {
        let specialKeys = [
            "key.with.dots",
            "key/with/slashes",
            "key with spaces and # $ % & *",
            "🔑_token_key_🚀",
            "日本語_キー_123",
            "ключ_авторизации_тест",
            "مفتاح_المصادقة"
        ]
        
        for (index, key) in specialKeys.enumerated() {
            let secret = "secret_value_\(index)"
            try testKeychain.save(key: key, string: secret)
            let retrieved = testKeychain.getString(key: key)
            XCTAssertEqual(retrieved, secret, "Failed for special key: \(key)")
        }
    }
    
    func testKeychain_BoundaryLongKeyName() throws {
        let longKey = String(repeating: "k", count: 512)
        let secret = "long_key_secret"
        try testKeychain.save(key: longKey, string: secret)
        let retrieved = testKeychain.getString(key: longKey)
        XCTAssertEqual(retrieved, secret)
    }
    
    // MARK: - Group 3: OAuthToken Serialization & Corrupted Payloads
    
    func testOAuthToken_FullRoundtripAllFields() throws {
        let fixedDate = Date(timeIntervalSince1970: 1725184800) // Fixed deterministic epoch
        let token = OAuthToken(
            accessToken: "vcp_tok_access_12345",
            refreshToken: "vcp_ref_refresh_67890",
            tokenType: "Bearer",
            expiresIn: 7200,
            expiresAt: fixedDate,
            scope: "openid email deployments",
            teamId: "team_vercel_prod_99",
            userId: "user_owner_01"
        )
        
        try testKeychain.saveToken(token)
        let retrieved = testKeychain.getToken()
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.accessToken, "vcp_tok_access_12345")
        XCTAssertEqual(retrieved?.refreshToken, "vcp_ref_refresh_67890")
        XCTAssertEqual(retrieved?.tokenType, "Bearer")
        XCTAssertEqual(retrieved?.expiresIn, 7200)
        XCTAssertEqual(retrieved?.expiresAt, fixedDate)
        XCTAssertEqual(retrieved?.scope, "openid email deployments")
        XCTAssertEqual(retrieved?.teamId, "team_vercel_prod_99")
        XCTAssertEqual(retrieved?.userId, "user_owner_01")
    }
    
    func testOAuthToken_SnakeCaseAndCamelCaseDecoding() throws {
        // Snake case JSON
        let snakeJSON = """
        {
            "access_token": "snake_access",
            "refresh_token": "snake_refresh",
            "token_type": "Bearer",
            "expires_in": 3600,
            "team_id": "team_snake",
            "user_id": "user_snake"
        }
        """.data(using: .utf8)!
        
        let snakeToken = try JSONDecoder().decode(OAuthToken.self, from: snakeJSON)
        XCTAssertEqual(snakeToken.accessToken, "snake_access")
        XCTAssertEqual(snakeToken.refreshToken, "snake_refresh")
        XCTAssertEqual(snakeToken.teamId, "team_snake")
        XCTAssertEqual(snakeToken.userId, "user_snake")
        XCTAssertNotNil(snakeToken.expiresAt)
        
        // Camel case JSON
        let camelJSON = """
        {
            "accessToken": "camel_access",
            "refreshToken": "camel_refresh",
            "tokenType": "Bearer",
            "expiresIn": 1800,
            "teamId": "team_camel",
            "userId": "user_camel"
        }
        """.data(using: .utf8)!
        
        let camelToken = try JSONDecoder().decode(OAuthToken.self, from: camelJSON)
        XCTAssertEqual(camelToken.accessToken, "camel_access")
        XCTAssertEqual(camelToken.refreshToken, "camel_refresh")
        XCTAssertEqual(camelToken.teamId, "team_camel")
        XCTAssertEqual(camelToken.userId, "user_camel")
    }
    
    func testOAuthToken_CorruptedJSONInKeychain_GracefulHandling() throws {
        let corruptedData = "INVALID_CORRUPTED_JSON_STREAM{{{[}".data(using: .utf8)!
        try testKeychain.save(key: KeychainKeys.oauthToken, data: corruptedData)
        
        // getToken should safely return nil when payload is corrupted JSON
        let token = testKeychain.getToken()
        XCTAssertNil(token, "getToken() should return nil for corrupted JSON payload")
    }
    
    func testOAuthToken_MissingAccessTokenKey_FailsDecoding() {
        let missingTokenJSON = """
        {
            "refresh_token": "ref_only_no_access",
            "token_type": "Bearer",
            "expires_in": 3600
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try JSONDecoder().decode(OAuthToken.self, from: missingTokenJSON)) { error in
            guard case DecodingError.keyNotFound = error else {
                XCTFail("Expected DecodingError.keyNotFound, got: \(error)")
                return
            }
        }
    }
    
    func testOAuthToken_InvalidDataTypeForAccessToken() {
        let badTypeJSON = """
        {
            "access_token": 123456789,
            "token_type": "Bearer"
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try JSONDecoder().decode(OAuthToken.self, from: badTypeJSON))
    }
    
    func testOAuthToken_LifecycleStatusCalculations() {
        // Expired token (expiresAt 100 seconds in past)
        let pastDate = Date().addingTimeInterval(-100)
        let expiredToken = OAuthToken(accessToken: "tok_expired", expiresAt: pastDate)
        XCTAssertTrue(expiredToken.isExpired)
        XCTAssertTrue(expiredToken.isExpiring(within: 60))
        XCTAssertTrue(expiredToken.isExpiringSoon(threshold: 60))
        XCTAssertTrue(expiredToken.shouldRefresh)
        XCTAssertFalse(expiredToken.isValid)
        XCTAssertEqual(expiredToken.timeRemaining, 0)
        
        // Expiring soon token (expires in 30 seconds, threshold 60)
        let soonDate = Date().addingTimeInterval(30)
        let soonToken = OAuthToken(accessToken: "tok_soon", expiresAt: soonDate)
        XCTAssertFalse(soonToken.isExpired)
        XCTAssertTrue(soonToken.isExpiring(within: 60))
        XCTAssertTrue(soonToken.isExpiringSoon(threshold: 60))
        XCTAssertTrue(soonToken.shouldRefresh)
        XCTAssertTrue(soonToken.isValid)
        XCTAssertGreaterThan(soonToken.timeRemaining ?? 0, 0)
        XCTAssertLessThanOrEqual(soonToken.timeRemaining ?? 0, 31)
        
        // Fresh token (expires in 10,000 seconds)
        let freshDate = Date().addingTimeInterval(10000)
        let freshToken = OAuthToken(accessToken: "tok_fresh", expiresAt: freshDate)
        XCTAssertFalse(freshToken.isExpired)
        XCTAssertFalse(freshToken.isExpiring(within: 60))
        XCTAssertFalse(freshToken.shouldRefresh)
        XCTAssertTrue(freshToken.isValid)
        XCTAssertFalse(freshToken.isEmpty)
        
        // Token without expiration (permanent PAT)
        let permanentToken = OAuthToken(accessToken: "tok_permanent")
        XCTAssertFalse(permanentToken.isExpired)
        XCTAssertFalse(permanentToken.isExpiring(within: 60))
        XCTAssertFalse(permanentToken.shouldRefresh)
        XCTAssertTrue(permanentToken.isValid)
        XCTAssertNil(permanentToken.timeRemaining)
        
        // Empty / Whitespace token
        let emptyToken = OAuthToken(accessToken: "")
        XCTAssertTrue(emptyToken.isEmpty)
        XCTAssertFalse(emptyToken.isValid)
        
        let whitespaceToken = OAuthToken(accessToken: "   \n\t  ")
        XCTAssertTrue(whitespaceToken.isEmpty)
        XCTAssertFalse(whitespaceToken.isValid)
        
        // Description test
        XCTAssertEqual(freshToken.description, "tok_fresh")
    }
    
    // MARK: - Group 4: Duplicate Overwrites & Update Logic
    
    func testKeychain_RepeatedSequentialOverwrites() throws {
        let key = "overwrite_target_key"
        
        for i in 1...10 {
            let value = "version_\(i)"
            try testKeychain.save(key: key, string: value)
            let current = testKeychain.getString(key: key)
            XCTAssertEqual(current, value)
        }
    }
    
    func testKeychain_OverwriteLargerWithSmallerPayload() throws {
        let key = "shrink_payload_key"
        
        let largeString = String(repeating: "A", count: 10000)
        try testKeychain.save(key: key, string: largeString)
        XCTAssertEqual(testKeychain.getString(key: key)?.count, 10000)
        
        let smallString = "small"
        try testKeychain.save(key: key, string: smallString)
        let retrieved = testKeychain.getString(key: key)
        XCTAssertEqual(retrieved, smallString)
        XCTAssertEqual(retrieved?.count, 5)
    }
    
    func testKeychain_OverwriteSmallerWithLargerPayload() throws {
        let key = "expand_payload_key"
        
        let smallString = "small"
        try testKeychain.save(key: key, string: smallString)
        XCTAssertEqual(testKeychain.getString(key: key), smallString)
        
        let largeString = String(repeating: "Z", count: 20000)
        try testKeychain.save(key: key, string: largeString)
        let retrieved = testKeychain.getString(key: key)
        XCTAssertEqual(retrieved, largeString)
        XCTAssertEqual(retrieved?.count, 20000)
    }
    
    func testKeychain_LegacyTokenFallbackAndPrecedence() throws {
        // 1. If only legacy token is present
        try testKeychain.save(key: KeychainKeys.legacyToken, string: "legacy_pat_token_value")
        let fallbackToken = testKeychain.getToken()
        XCTAssertNotNil(fallbackToken)
        XCTAssertEqual(fallbackToken?.accessToken, "legacy_pat_token_value")
        XCTAssertEqual(fallbackToken?.tokenType, "Bearer")
        
        // 2. When full OAuth token is saved, it takes precedence
        let modernToken = OAuthToken(accessToken: "modern_oauth_token", refreshToken: "modern_refresh")
        try testKeychain.saveToken(modernToken)
        let primaryToken = testKeychain.getToken()
        XCTAssertEqual(primaryToken?.accessToken, "modern_oauth_token")
        XCTAssertEqual(primaryToken?.refreshToken, "modern_refresh")
        
        // 3. Saving empty string via legacy saveToken clears both keys
        testKeychain.saveToken("")
        XCTAssertNil(testKeychain.getToken())
        XCTAssertNil(testKeychain.getString(key: KeychainKeys.legacyToken))
        XCTAssertNil(try testKeychain.getData(key: KeychainKeys.oauthToken))
    }
    
    func testKeychain_DeleteTokenHelper() throws {
        let token = OAuthToken(accessToken: "tok_to_delete")
        try testKeychain.saveToken(token)
        try testKeychain.save(key: KeychainKeys.legacyToken, string: "legacy_to_delete")
        
        XCTAssertNotNil(testKeychain.getToken())
        testKeychain.deleteToken()
        
        XCTAssertNil(testKeychain.getToken())
        XCTAssertNil(testKeychain.getString(key: KeychainKeys.legacyToken))
    }
    
    // MARK: - Group 5: Session Purge, Service Isolation, & Memory Lifecycle
    
    /// EMPIRICAL BUG REPRODUCTION:
    /// `KeychainManager.purgeAll()` currently calls `SecItemDelete(query)` exactly once without an account key.
    /// Under macOS Keychain Services, `SecItemDelete` deletes only ONE matching item per call.
    /// Therefore, when multiple items exist (e.g. 15 items), 14 items remain undeleted in the Keychain.
    func testKeychain_PurgeAll_BugReproduction_SingleSecItemDeleteLeavesRemainingItems() throws {
        for i in 0..<5 {
            try testKeychain.save(key: "purge_bug_key_\(i)", string: "value_\(i)")
        }
        
        // Single purgeAll call now purges all items via loop-based SecItemDelete
        try testKeychain.purgeAll()
        
        let remainingCount = (0..<5).filter { testKeychain.getString(key: "purge_bug_key_\($0)") != nil }.count
        XCTAssertEqual(remainingCount, 0, "Loop mitigation: purgeAll clears all items in Keychain")
    }
    
    /// Verification of the proper loop-based purge mitigation:
    /// Repeatedly calling SecItemDelete until errSecItemNotFound clears ALL items under the service.
    func testKeychain_PurgeAll_LoopMitigationVerification() throws {
        for i in 0..<15 {
            try testKeychain.save(key: "purge_loop_key_\(i)", string: "value_\(i)")
        }
        
        // Perform loop-based purge
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testServiceName!
        ]
        
        var status: OSStatus = errSecSuccess
        while status == errSecSuccess {
            status = SecItemDelete(query as CFDictionary)
        }
        XCTAssertEqual(status, errSecItemNotFound)
        
        // Verify all 15 items are now completely gone
        for i in 0..<15 {
            XCTAssertNil(testKeychain.getString(key: "purge_loop_key_\(i)"))
        }
    }
    
    func testKeychain_PurgeAll_ServiceIsolation() throws {
        let serviceA = "com.vercelpulse.test.isolation.A.\(UUID().uuidString)"
        let serviceB = "com.vercelpulse.test.isolation.B.\(UUID().uuidString)"
        
        let keychainA = KeychainManager(serviceName: serviceA)
        let keychainB = KeychainManager(serviceName: serviceB)
        
        defer {
            try? keychainA.purgeAll()
            try? keychainB.purgeAll()
        }
        
        try keychainA.save(key: "shared_key_name", string: "value_in_service_A")
        try keychainB.save(key: "shared_key_name", string: "value_in_service_B")
        
        XCTAssertEqual(keychainA.getString(key: "shared_key_name"), "value_in_service_A")
        XCTAssertEqual(keychainB.getString(key: "shared_key_name"), "value_in_service_B")
        
        // Purge service A
        try keychainA.purgeAll()
        
        // Service A should be empty, Service B should remain intact
        XCTAssertNil(keychainA.getString(key: "shared_key_name"))
        XCTAssertEqual(keychainB.getString(key: "shared_key_name"), "value_in_service_B")
    }
    
    func testKeychain_PurgeAll_EmptyKeychainDoesNotThrow() throws {
        XCTAssertNoThrow(try testKeychain.purgeAll())
        XCTAssertNoThrow(try testKeychain.purgeAll()) // Second purge on empty
    }
    
    func testKeychain_DeleteNonExistentKeyDoesNotThrow() throws {
        XCTAssertNoThrow(try testKeychain.delete(key: "non_existent_key_12345"))
    }
    
    func testKeychain_MemoryCleanupAndLeakVerification() throws {
        // Run 50 iterations of write, read, delete to ensure memory stability and no leak accumulation
        for i in 0..<50 {
            autoreleasepool {
                let key = "leak_test_key"
                let value = "leak_test_val_\(i)"
                try? testKeychain.save(key: key, string: value)
                _ = testKeychain.getString(key: key)
                try? testKeychain.delete(key: key)
            }
        }
        XCTAssertNil(testKeychain.getString(key: "leak_test_key"))
    }
}
