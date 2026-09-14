import SwiftUI

/// Categorized error types for rich banner presentation.
public enum ErrorBannerType: Equatable {
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case networkOffline(String?)
    case forbidden
    case serverError(statusCode: Int, message: String?)
    case generic(String)
    
    public static func from(apiError: VercelAPIService.APIError) -> ErrorBannerType {
        switch apiError {
        case .unauthorized, .missingToken:
            return .unauthorized
        case .rateLimited(let retryAfter):
            return .rateLimited(retryAfter: retryAfter)
        case .networkError(let details):
            return .networkOffline(details)
        case .forbidden:
            return .forbidden
        case .serverError(let code, let msg):
            return .serverError(statusCode: code, message: msg)
        default:
            return .generic(apiError.localizedDescription)
        }
    }
    
    public static func from(message: String) -> ErrorBannerType {
        let lower = message.lowercased()
        if lower.contains("unauthorized") || lower.contains("expired") || lower.contains("missing token") {
            return .unauthorized
        } else if lower.contains("rate limit") || lower.contains("429") {
            return .rateLimited(retryAfter: nil)
        } else if lower.contains("offline") || lower.contains("network") || lower.contains("internet") {
            return .networkOffline(message)
        } else if lower.contains("forbidden") || lower.contains("403") {
            return .forbidden
        }
        return .generic(message)
    }
}

/// Categorized error banner displaying actionable guidance for 401, 429, offline, and generic API errors.
public struct ErrorBannerView: View {
    public let errorType: ErrorBannerType
    public var onRetry: (() -> Void)?
    public var onReauthenticate: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onDismiss: (() -> Void)?
    
    public init(
        errorType: ErrorBannerType,
        onRetry: (() -> Void)? = nil,
        onReauthenticate: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.errorType = errorType
        self.onRetry = onRetry
        self.onReauthenticate = onReauthenticate
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }
    
    public init(
        errorMessage: String,
        onRetry: (() -> Void)? = nil,
        onReauthenticate: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            errorType: ErrorBannerType.from(message: errorMessage),
            onRetry: onRetry,
            onReauthenticate: onReauthenticate,
            onOpenSettings: onOpenSettings,
            onDismiss: onDismiss
        )
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Error icon
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 20)
            
            // Text info
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(messageText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 4)
            
            // Action button
            actionButton
            
            // Dismiss button
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var actionButton: some View {
        switch errorType {
        case .unauthorized:
            if let onReauthenticate = onReauthenticate {
                Button(action: onReauthenticate) {
                    Text("Sign In")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            } else if let onOpenSettings = onOpenSettings {
                Button(action: onOpenSettings) {
                    Text("Settings")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
        case .rateLimited, .networkOffline, .serverError:
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8, weight: .bold))
                        Text("Retry")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.2))
                    .foregroundColor(accentColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
        case .forbidden:
            if let onOpenSettings = onOpenSettings {
                Button(action: onOpenSettings) {
                    Text("Settings")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.2))
                        .foregroundColor(accentColor)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
        case .generic:
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.2))
                        .foregroundColor(accentColor)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Properties
    
    private var iconName: String {
        switch errorType {
        case .unauthorized:
            return "lock.trianglebadge.exclamationmark.fill"
        case .rateLimited:
            return "hourglass"
        case .networkOffline:
            return "wifi.slash"
        case .forbidden:
            return "hand.raised.fill"
        case .serverError:
            return "exclamationmark.icloud.fill"
        case .generic:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var accentColor: Color {
        switch errorType {
        case .unauthorized:
            return Color.red
        case .rateLimited:
            return Color.orange
        case .networkOffline:
            return Color.orange
        case .forbidden:
            return Color.yellow
        case .serverError:
            return Color.red
        case .generic:
            return Color.red
        }
    }
    
    private var titleText: String {
        switch errorType {
        case .unauthorized:
            return "Session Expired"
        case .rateLimited:
            return "Rate Limit Exceeded"
        case .networkOffline:
            return "Network Offline"
        case .forbidden:
            return "Access Forbidden"
        case .serverError(let code, _):
            return "Vercel Server Error (\(code))"
        case .generic:
            return "Sync Error"
        }
    }
    
    private var messageText: String {
        switch errorType {
        case .unauthorized:
            return "Please re-authenticate with Vercel to resume live tracking."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "API quota reached. Polling paused for \(seconds)s."
            }
            return "API quota reached. Polling paused until reset."
        case .networkOffline(let details):
            return details ?? "Unable to connect to Vercel API. Check your internet."
        case .forbidden:
            return "Insufficient permissions for this workspace or team."
        case .serverError(_, let msg):
            return msg ?? "Vercel API service disruption encountered."
        case .generic(let msg):
            return msg
        }
    }
}
