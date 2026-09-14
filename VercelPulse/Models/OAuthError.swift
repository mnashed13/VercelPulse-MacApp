import Foundation

/// Standardized OAuth error model with localized user-friendly descriptions.
public enum OAuthError: Error, LocalizedError, Equatable, Sendable {
    case userCancelled
    case missingCallbackURL
    case missingAuthorizationCode
    case stateMismatch
    case stateMismatchDetails(expected: String, received: String)
    case invalidCallbackURL(String)
    case invalidConfiguration(String)
    case cryptoError(String)
    case sessionFailedToStart
    case serverError(error: String, description: String?)
    case accessDenied(String)
    case missingToken
    case missingRefreshToken
    case networkError(String)
    case tokenExchangeFailed(statusCode: Int, message: String)
    case tokenRefreshFailed(statusCode: Int, message: String)
    case refreshFailed(statusCode: Int, message: String)
    case decodingError(String)
    case keychainError(String)
    case unhandledError(String)
    
    public static func stateMismatch(expected: String, received: String) -> OAuthError {
        return .stateMismatchDetails(expected: expected, received: received)
    }
    
    public var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "The authentication session was cancelled."
        case .missingCallbackURL:
            return "No callback URL was received from the authentication provider."
        case .missingAuthorizationCode:
            return "No authorization code found in the callback response."
        case .stateMismatch:
            return "Security verification failed: Anti-CSRF state mismatch."
        case .stateMismatchDetails(let expected, let received):
            return "Security verification failed (state mismatch). Expected \(expected), received \(received)."
        case .invalidCallbackURL(let url):
            return "Invalid callback URL structure: \(url)"
        case .invalidConfiguration(let reason):
            return "Invalid OAuth configuration: \(reason)"
        case .cryptoError(let reason):
            return "Cryptographic operation failed: \(reason)"
        case .sessionFailedToStart:
            return "Failed to launch web authentication session."
        case .serverError(let error, let description):
            if let desc = description, !desc.isEmpty {
                return "Authentication server error: \(error) - \(desc)"
            }
            return "Authentication server error: \(error)"
        case .accessDenied(let desc):
            return "Access denied by Vercel: \(desc)"
        case .missingToken:
            return "No active access token found. Please sign in."
        case .missingRefreshToken:
            return "No refresh token available to renew credentials."
        case .networkError(let msg):
            return "Network connection error: \(msg)"
        case .tokenExchangeFailed(let status, let msg):
            return "Token exchange failed with HTTP \(status): \(msg)"
        case .tokenRefreshFailed(let status, let msg), .refreshFailed(let status, let msg):
            return "Token refresh failed with HTTP \(status): \(msg)"
        case .decodingError(let msg):
            return "Failed to parse authentication response: \(msg)"
        case .keychainError(let msg):
            return "Keychain storage failure: \(msg)"
        case .unhandledError(let msg):
            return "Unhandled authentication error: \(msg)"
        }
    }
}
