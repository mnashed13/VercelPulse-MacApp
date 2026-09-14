import Foundation
import CryptoKit
import Security

/// Represents an RFC 7636 PKCE Verifier and Challenge Pair.
public struct PKCEPair: Equatable, Sendable {
    public let codeVerifier: String
    public let codeChallenge: String
    public let codeChallengeMethod: String
    
    public init(codeVerifier: String, codeChallenge: String, codeChallengeMethod: String = "S256") {
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
    }
}

/// Helper for generating PKCE RFC 7636 code verifiers and S256 code challenges.
public enum PKCEHelper {
    
    /// Generates a cryptographically random 32-byte (256-bit) verifier and its SHA-256 S256 challenge.
    public static func generate() throws -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw OAuthError.cryptoError("Failed to generate cryptographically random bytes for PKCE (OSStatus: \(status))")
        }
        
        let verifier = Data(bytes).base64URLEncodedString()
        let challenge = computeChallenge(for: verifier)
        
        return PKCEPair(codeVerifier: verifier, codeChallenge: challenge, codeChallengeMethod: "S256")
    }
    
    /// Computes RFC 7636 Base64URL(SHA256(verifier)) challenge.
    public static func computeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }
    
    /// Generates a code verifier of specified length (clamped between 43 and 128 chars per RFC 7636).
    public static func generateCodeVerifier(length: Int = 64) -> String {
        let clampedLength = min(max(length, 43), 128)
        let unreservedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        var randomBytes = [UInt8](repeating: 0, count: clampedLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, clampedLength, &randomBytes)
        
        if status == errSecSuccess {
            var result = ""
            result.reserveCapacity(clampedLength)
            let charsetArray = Array(unreservedCharacters)
            for byte in randomBytes {
                let index = Int(byte) % charsetArray.count
                result.append(charsetArray[index])
            }
            return result
        } else {
            // Fallback to Swift standard RNG if SecRandomCopyBytes is unavailable
            return String((0..<clampedLength).compactMap { _ in unreservedCharacters.randomElement() })
        }
    }
    
    /// Generates a code challenge from a verifier string (alias for computeChallenge).
    public static func generateCodeChallenge(from verifier: String) -> String {
        return computeChallenge(for: verifier)
    }
}

public extension Data {
    /// Converts binary data to RFC 4648 Base64URL format (+ -> -, / -> _, trim =).
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}
