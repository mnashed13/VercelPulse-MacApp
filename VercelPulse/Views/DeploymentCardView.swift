import SwiftUI
import AppKit

/// Modern, rich deployment card view displaying lifecycle status, Git metadata, and deep link actions.
public struct DeploymentCardView: View {
    public let deployment: Deployment
    public var teamSlug: String?
    public var username: String?
    
    @State private var isHovered = false
    @State private var hasCopied = false
    
    public init(
        deployment: Deployment,
        teamSlug: String? = nil,
        username: String? = nil
    ) {
        self.deployment = deployment
        self.teamSlug = teamSlug
        self.username = username
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Status accent bar on the leading edge
            RoundedRectangle(cornerRadius: 1.5)
                .fill(deployment.status.color)
                .frame(width: 3.5)
                .padding(.vertical, 4)
                .padding(.leading, 3)
                .opacity(deployment.status == .ready ? 0.75 : 1.0)
            
            VStack(alignment: .leading, spacing: 7) {
                // MARK: - Top Row: Project Name + Target Pill + State Badge
                HStack(alignment: .center, spacing: 6) {
                    Text(deployment.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    targetPill
                    
                    Spacer(minLength: 4)
                    
                    stateBadge
                }
                
                // MARK: - Middle Row: Branch + Commit Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(branchName)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.85))
                            .lineLimit(1)
                        
                        if let sha = deployment.meta?.shortSha {
                            Text("@\(sha)")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let commit = commitMessage {
                        Text(commit)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // MARK: - In-Progress / Failed State Banner
                buildStateBanner
                
                // MARK: - Bottom Row: Author + Timestamp + Duration + Action Buttons
                HStack(alignment: .center, spacing: 5) {
                    // Author info
                    HStack(spacing: 3) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(authorName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: 80, alignment: .leading)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    // Timestamp & Duration
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        
                        Text(deployment.relativeCreatedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Action Buttons
                    actionButtons
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 9)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    statusBorderColor,
                    lineWidth: deployment.status.isInProgress ? 1.5 : 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Subviews
    
    private var statusBorderColor: Color {
        let status = deployment.status
        if isHovered {
            return status.color.opacity(0.45)
        }
        if status.isInProgress {
            return status.color.opacity(0.35)
        }
        if status.isFailed {
            return status.color.opacity(0.3)
        }
        return Color.primary.opacity(0.08)
    }
    
    @ViewBuilder
    private var buildStateBanner: some View {
        let status = deployment.status
        if status.isInProgress {
            HStack(spacing: 6) {
                if status == .building {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                    Text("Building deployment in progress...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(status.color)
                        .lineLimit(1)
                } else if status == .queued {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(status.color)
                    Text("Queued in build pipeline...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(status.color)
                        .lineLimit(1)
                } else {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(status.color)
                    Text("Initializing deployment...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(status.color)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                if let duration = deployment.durationFormatted {
                    Text(duration)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(status.color.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(status.color.opacity(0.1))
            )
        } else if status == .error {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.red)
                Text("Build failed • Inspect logs for details")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.09))
            )
        } else if status == .canceled {
            HStack(spacing: 5) {
                Image(systemName: "slash.circle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Build canceled • Deployment stopped")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.09))
            )
        }
    }
    
    @ViewBuilder
    private var targetPill: some View {
        if deployment.isProduction {
            Text("PROD")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.18))
                )
                .foregroundColor(Color.purple)
        } else {
            Text("PREV")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.15))
                )
                .foregroundColor(Color.blue)
        }
    }
    
    @ViewBuilder
    private var stateBadge: some View {
        let status = deployment.status
        HStack(spacing: 3.5) {
            if status == .building {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
            } else if status == .queued {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 8.5, weight: .bold))
            } else {
                Image(systemName: status.iconName)
                    .font(.system(size: 8.5, weight: .bold))
            }
            
            Text(status.displayName.uppercased())
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(status.color.opacity(0.16))
        )
        .foregroundColor(status.color)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            // Copy URL button
            Button(action: copyDeploymentURL) {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(hasCopied ? .green : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .help("Copy Deployment URL")
            
            // Preview Web App button (Active when READY, disabled when building/failed)
            if deployment.status.isLive, let previewURL = VercelDeepLinkHelper.previewURL(for: deployment) {
                Button(action: {
                    VercelDeepLinkHelper.openInBrowser(previewURL)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.system(size: 9))
                        Text("Preview")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .foregroundColor(.primary.opacity(0.9))
                }
                .buttonStyle(.plain)
                .help("Open Live Preview")
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "eye")
                        .font(.system(size: 9))
                    Text("Preview")
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.02))
                )
                .foregroundColor(.secondary.opacity(0.35))
                .help(previewUnavailableHelpText)
            }
            
            // Inspect in Vercel Dashboard button (Highlighted when building/queued/error)
            Button(action: {
                let dashboardURL = VercelDeepLinkHelper.webDashboardURL(
                    for: deployment,
                    teamSlug: teamSlug,
                    username: username
                )
                VercelDeepLinkHelper.openInBrowser(dashboardURL)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9, weight: deployment.status.isInProgress || deployment.status.isFailed ? .semibold : .medium))
                    Text("Inspect")
                        .font(.system(size: 10, weight: deployment.status.isInProgress || deployment.status.isFailed ? .semibold : .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(inspectButtonBackgroundColor)
                )
                .foregroundColor(inspectButtonForegroundColor)
            }
            .buttonStyle(.plain)
            .help(inspectButtonHelpText)
        }
    }
    
    private var previewUnavailableHelpText: String {
        switch deployment.status {
        case .queued:
            return "Build is queued — preview not ready yet"
        case .building:
            return "Build in progress — preview not ready yet"
        case .initializing:
            return "Initializing deployment — preview not ready yet"
        case .error:
            return "Build failed — preview unavailable"
        case .canceled:
            return "Build was canceled — preview unavailable"
        default:
            return "Preview unavailable"
        }
    }
    
    private var inspectButtonBackgroundColor: Color {
        let status = deployment.status
        if status.isInProgress {
            return status.color.opacity(0.18)
        }
        if status.isFailed {
            return Color.red.opacity(0.18)
        }
        return Color.accentColor.opacity(0.12)
    }
    
    private var inspectButtonForegroundColor: Color {
        let status = deployment.status
        if status.isInProgress {
            return status.color
        }
        if status.isFailed {
            return Color.red
        }
        return .accentColor
    }
    
    private var inspectButtonHelpText: String {
        let status = deployment.status
        if status.isInProgress {
            return "Inspect Live Build Logs in Vercel"
        }
        if status.isFailed {
            return "Inspect Build Failure in Vercel"
        }
        return "Open in Vercel Dashboard"
    }
    
    // MARK: - Helpers
    
    private var branchName: String {
        deployment.meta?.branchName ?? (deployment.isProduction ? "main" : "preview")
    }
    
    private var commitMessage: String? {
        if let msg = deployment.meta?.commitMessage, !msg.isEmpty {
            return msg
        }
        return "Manual deployment"
    }
    
    private var authorName: String {
        if let author = deployment.meta?.authorName, !author.isEmpty {
            return author
        }
        if let creator = deployment.creator?.username, !creator.isEmpty {
            return creator
        }
        return "Anonymous"
    }
    
    private func copyDeploymentURL() {
        let urlStringToCopy: String
        if let previewURL = VercelDeepLinkHelper.previewURL(for: deployment) {
            urlStringToCopy = previewURL.absoluteString
        } else {
            urlStringToCopy = deployment.url
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urlStringToCopy, forType: .string)
        
        withAnimation {
            hasCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                hasCopied = false
            }
        }
    }
}
