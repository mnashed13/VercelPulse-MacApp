import SwiftUI
import AppKit

/// Liquid Glass deployment card displaying lifecycle status, Git metadata, and interactive glass actions.
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
            // Subtle luminous status accent bar on the leading edge
            Capsule()
                .fill(deployment.status.color)
                .frame(width: 3.5)
                .padding(.vertical, 8)
                .padding(.leading, 5)
                .opacity(deployment.status == .ready ? 0.8 : 1.0)
                .shadow(color: deployment.status.color.opacity(0.45), radius: 3, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 8) {
                // MARK: - Top Row: Project Name + Target Pill + State Badge
                HStack(alignment: .center, spacing: 6) {
                    Text(deployment.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    targetPill
                    
                    Spacer(minLength: 4)
                    
                    stateBadge
                }
                
                // MARK: - Middle Row: Branch Pill + Commit Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Text(branchName)
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.9))
                            .lineLimit(1)
                        
                        if let sha = deployment.meta?.shortSha {
                            Text("@\(sha)")
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
                    
                    if let commit = commitMessage {
                        Text(commit)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // MARK: - In-Progress / Failed State Banner
                buildStateBanner
                
                // MARK: - Bottom Row: Author + Timestamp + Liquid Glass Action Pills
                HStack(alignment: .center, spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        Text(authorName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: 76, alignment: .leading)
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    
                    HStack(spacing: 2.5) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        
                        Text(deployment.relativeCreatedTime)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    Spacer(minLength: 4)
                    
                    actionButtons
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, 11)
            .padding(.vertical, 10)
        }
        .liquidGlassCard(
            cornerRadius: 16,
            tint: cardTintColor,
            borderColor: statusBorderColor,
            borderWidth: deployment.status.isInProgress ? 1.25 : 0.85,
            isHovered: isHovered
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Subviews
    
    private var cardTintColor: Color? {
        if deployment.status.isInProgress || deployment.status.isFailed {
            return deployment.status.color
        }
        return nil
    }
    
    private var statusBorderColor: Color {
        let status = deployment.status
        if isHovered {
            return status.color.opacity(0.55)
        }
        if status.isInProgress {
            return status.color.opacity(0.42)
        }
        if status.isFailed {
            return status.color.opacity(0.36)
        }
        return Color.white.opacity(0.24)
    }
    
    @ViewBuilder
    private var buildStateBanner: some View {
        let status = deployment.status
        if status.isInProgress {
            HStack(spacing: 6) {
                if status == .building {
                    ProgressView()
                        .scaleEffect(0.52)
                        .frame(width: 11, height: 11)
                    Text("Building deployment in progress...")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                } else if status == .queued {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(status.color)
                    Text("Queued in build pipeline...")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                } else {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(status.color)
                    Text("Initializing deployment...")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(status.color)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                if let duration = deployment.durationFormatted {
                    Text(duration)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(status.color.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(status.color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(status.color.opacity(0.22), lineWidth: 0.75)
            )
        } else if status == .error {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.red)
                Text("Build failed • Inspect logs for details")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.22), lineWidth: 0.75)
            )
        } else if status == .canceled {
            HStack(spacing: 5) {
                Image(systemName: "slash.circle.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Build canceled • Deployment stopped")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }
    
    @ViewBuilder
    private var targetPill: some View {
        if deployment.isProduction {
            Text("PROD")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.purple.opacity(0.28), lineWidth: 0.6)
                )
                .foregroundStyle(.purple)
        } else {
            Text("PREV")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 0.6)
                )
                .foregroundStyle(.blue)
        }
    }
    
    @ViewBuilder
    private var stateBadge: some View {
        let status = deployment.status
        HStack(spacing: 3.5) {
            if status == .building {
                ProgressView()
                    .scaleEffect(0.48)
                    .frame(width: 10, height: 10)
            } else if status == .queued {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 8.5, weight: .bold))
            } else {
                Image(systemName: status.iconName)
                    .font(.system(size: 8.5, weight: .bold))
            }
            
            Text(status.displayName.uppercased())
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(status.color.opacity(0.28), lineWidth: 0.6)
        )
        .foregroundStyle(status.color)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                // Copy URL button
                Button(action: copyDeploymentURL) {
                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(hasCopied ? .green : .secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .liquidGlassCircleControl(tint: hasCopied ? Color.green.opacity(0.2) : nil)
                .help("Copy Deployment URL")
                
                // Preview Web App button (Active when READY, muted when building/failed)
                if deployment.status.isLive, let previewURL = VercelDeepLinkHelper.previewURL(for: deployment) {
                    Button(action: {
                        VercelDeepLinkHelper.openInBrowser(previewURL)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "eye")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Preview")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.primary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .liquidGlassControl()
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.03))
                    )
                    .foregroundStyle(.tertiary)
                    .help(previewUnavailableHelpText)
                }
                
                // Inspect in Vercel Dashboard button
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
                            .font(.system(size: 9, weight: .semibold))
                        Text("Inspect")
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(inspectButtonForegroundColor)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .liquidGlassControl(tint: inspectButtonGlassTint)
                .help(inspectButtonHelpText)
            }
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
    
    private var inspectButtonGlassTint: Color {
        let status = deployment.status
        if status.isInProgress {
            return status.color.opacity(0.24)
        }
        if status.isFailed {
            return Color.red.opacity(0.24)
        }
        return Color.accentColor.opacity(0.16)
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
