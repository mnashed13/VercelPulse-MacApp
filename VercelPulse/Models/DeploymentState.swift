import Foundation
import SwiftUI

/// Lifecycle states for Vercel deployments.
public enum DeploymentState: String, Codable, CaseIterable, Sendable {
    case initializing = "INITIALIZING"
    case queued = "QUEUED"
    case building = "BUILDING"
    case ready = "READY"
    case error = "ERROR"
    case canceled = "CANCELED"
    case unknown = "UNKNOWN"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self.init(apiState: raw)
    }
    
    public init(apiState: String?) {
        guard let state = apiState?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines), !state.isEmpty else {
            self = .unknown
            return
        }
        switch state {
        case "READY", "SUCCESS", "SUCCEEDED":
            self = .ready
        case "BUILDING", "IN_PROGRESS", "DEPLOYING":
            self = .building
        case "QUEUED", "PENDING":
            self = .queued
        case "INITIALIZING":
            self = .initializing
        case "ERROR", "FAILED", "FAILURE":
            self = .error
        case "CANCELED", "CANCELLED":
            self = .canceled
        default:
            self = DeploymentState(rawValue: state) ?? .unknown
        }
    }
    
    /// Indicates whether the deployment is ready and currently serving traffic.
    public var isLive: Bool {
        self == .ready
    }
    
    /// Indicates whether the deployment is actively processing (building, queued, or initializing).
    public var isInProgress: Bool {
        self == .building || self == .queued || self == .initializing
    }
    
    /// Alias for `isInProgress` for polling checks.
    public var isActive: Bool {
        isInProgress
    }
    
    /// Indicates whether the deployment resulted in failure or cancellation.
    public var isFailed: Bool {
        self == .error || self == .canceled
    }
    
    /// Indicates whether the deployment has reached a terminal status.
    public var isFinal: Bool {
        self == .ready || self == .error || self == .canceled
    }
    
    /// User-facing display title for the status.
    public var displayName: String {
        switch self {
        case .initializing: return "Initializing"
        case .queued: return "Queued"
        case .building: return "Building"
        case .ready: return "Ready"
        case .error: return "Error"
        case .canceled: return "Canceled"
        case .unknown: return "Unknown"
        }
    }
    
    /// SF Symbol icon name corresponding to this state.
    public var iconName: String {
        switch self {
        case .initializing: return "hourglass"
        case .queued: return "clock.arrow.circlepath"
        case .building: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .canceled: return "slash.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    /// Visual theme color for status badges and indicators.
    public var color: Color {
        switch self {
        case .ready: return Color(red: 16/255, green: 185/255, blue: 129/255) // Emerald #10B981
        case .building: return Color(red: 59/255, green: 130/255, blue: 246/255) // Sky Blue #3B82F6
        case .queued, .initializing: return Color(red: 245/255, green: 158/255, blue: 11/255) // Amber #F59E0B
        case .error: return Color(red: 239/255, green: 68/255, blue: 68/255) // Red #EF4444
        case .canceled: return Color(red: 107/255, green: 114/255, blue: 128/255) // Gray #6B7280
        case .unknown: return Color.gray
        }
    }
    
    /// System badge color name token for styling and tests.
    public var statusBadgeColorName: String {
        switch self {
        case .ready: return "systemGreen"
        case .building, .queued, .initializing: return "systemBlue"
        case .error: return "systemRed"
        case .canceled, .unknown: return "systemGray"
        }
    }
}
