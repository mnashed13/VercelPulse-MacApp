import SwiftUI

/// Main macOS Menu Bar popover view styled with macOS Liquid Glass, housing the deployment
/// dashboard, segmented scope filter, live pulse pill, error banners, and usage analytics.
public struct PopoverView: View {
    @ObservedObject public var viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    
    @State private var isSpinningRefresh = false
    @State private var showingSettingsSheet = false
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Floating Liquid Glass Header
            headerView
            
            LiquidGlassDivider()
                .padding(.horizontal, 12)
            
            // MARK: - Body Content
            if !viewModel.isAuthenticated {
                UnauthenticatedOnboardingView(
                    isAuthenticating: viewModel.isAuthenticating,
                    onSignIn: {
                        viewModel.startOAuthLogin()
                    },
                    onOpenSettings: {
                        openSettings()
                    },
                    onSavePAT: { token in
                        viewModel.savePAT(token: token)
                    }
                )
            } else {
                authenticatedDashboardView
            }
            
            LiquidGlassDivider()
                .padding(.horizontal, 12)
            
            // MARK: - Translucent Glass Footer
            footerView
        }
        .frame(width: 392, height: 556)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // Subtle top specular light bloom for depth
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    // MARK: - Floating Liquid Glass Header
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // Official Vercel Logo Badge, Title & Live Status Capsule
            HStack(spacing: 8) {
                ZStack {
                    VercelLogoView(size: 11, color: .primary)
                        .offset(y: -0.5)
                }
                .frame(width: 26, height: 26)
                .glassEffect(.regular, in: .circle)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("VercelPulse")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        pulseSyncPill
                    }
                }
            }
            
            Spacer(minLength: 6)
            
            // Liquid Glass Toolbar Cluster
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 5) {
                    // Manual Refresh Button
                    Button(action: {
                        triggerManualRefresh()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11.5, weight: .semibold))
                            .symbolEffect(.rotate, isActive: isSpinningRefresh || viewModel.isLoading)
                            .foregroundStyle(viewModel.isLoading ? .tertiary : .primary)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .liquidGlassCircleControl()
                    .disabled(viewModel.isLoading)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh Deployments (⌘R)")
                    
                    // Web Dashboard Quick Link
                    Button(action: {
                        openWebDashboard()
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .liquidGlassCircleControl()
                    .keyboardShortcut("o", modifiers: .command)
                    .help("Open Vercel Web Dashboard (⌘O)")
                    
                    // Settings & App Commands Menu
                    Menu {
                        Button {
                            openSettings()
                        } label: {
                            Label("Settings...", systemImage: "gearshape")
                        }
                        .keyboardShortcut(",", modifiers: .command)
                        
                        Button {
                            openWebDashboard()
                        } label: {
                            Label("Open Vercel Dashboard", systemImage: "arrow.up.right.square")
                        }
                        
                        Button {
                            triggerManualRefresh()
                        } label: {
                            Label("Refresh Deployments", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("Quit VercelPulse", systemImage: "power")
                        }
                        .keyboardShortcut("q", modifiers: .command)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                            .liquidGlassCircleControl()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Settings & Options")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Pulse Sync Pill
    
    @ViewBuilder
    private var pulseSyncPill: some View {
        let indicatorColor: Color = {
            if viewModel.deployments.isEmpty && viewModel.isLoading {
                return .blue
            } else if viewModel.errorMessage != nil && viewModel.deployments.isEmpty {
                return .red
            } else {
                return viewModel.pulseStatusColor
            }
        }()
        
        let statusText: String = {
            if viewModel.deployments.isEmpty && viewModel.isLoading {
                return "Syncing"
            } else if viewModel.errorMessage != nil && viewModel.deployments.isEmpty {
                return "Error"
            } else {
                return viewModel.pulseStatusText
            }
        }()
        
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 6, height: 6)
                .shadow(color: indicatorColor.opacity(0.65), radius: 3, x: 0, y: 0)
            
            Text(statusText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    viewModel.hasActiveBuilds || indicatorColor == .red
                        ? indicatorColor
                        : .secondary
                )
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .glassEffect(.regular.tint(indicatorColor.opacity(0.14)), in: .capsule)
    }
    
    // MARK: - Authenticated Dashboard
    
    private var authenticatedDashboardView: some View {
        VStack(spacing: 10) {
            // Segmented Liquid Glass Scope Filter Bar
            FilterScopeBar(
                selectedScope: $viewModel.selectedScope,
                allCount: viewModel.allCount,
                prodCount: viewModel.productionCount,
                prevCount: viewModel.previewCount
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            
            // Error Banner (if any)
            if let error = viewModel.activeAPIError {
                ErrorBannerView(
                    errorType: ErrorBannerType.from(apiError: error),
                    onRetry: {
                        triggerManualRefresh()
                    },
                    onReauthenticate: {
                        viewModel.startOAuthLogin()
                    },
                    onOpenSettings: {
                        openSettings()
                    },
                    onDismiss: {
                        viewModel.activeAPIError = nil
                        viewModel.errorMessage = nil
                    }
                )
                .padding(.horizontal, 12)
            } else if let errorMsg = viewModel.errorMessage {
                ErrorBannerView(
                    errorMessage: errorMsg,
                    onRetry: {
                        triggerManualRefresh()
                    },
                    onReauthenticate: {
                        viewModel.startOAuthLogin()
                    },
                    onOpenSettings: {
                        openSettings()
                    },
                    onDismiss: {
                        viewModel.errorMessage = nil
                    }
                )
                .padding(.horizontal, 12)
            }
            
            // Deployment List or Empty/Loading States
            if viewModel.isLoading && viewModel.deployments.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Text("Fetching deployments...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredDeployments.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredDeployments) { deployment in
                            DeploymentCardView(
                                deployment: deployment,
                                teamSlug: viewModel.effectiveTeamSlug,
                                username: viewModel.currentUsername
                            )
                            .id(deployment.idAndState)
                        }
                        
                        // Workspace Usage Section
                        if let usage = viewModel.usage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 5) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("Account Usage")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                                
                                UsageMetricsView(usage: usage)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            
            ZStack {
                Image(systemName: "shippingbox")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 54, height: 54)
            .glassEffect(.regular, in: .circle)
            
            VStack(spacing: 4) {
                Text("No \(viewModel.selectedScope.title.lowercased()) deployments")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Deployments pushed to Vercel will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            
            Button(action: {
                triggerManualRefresh()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack(spacing: 8) {
            // Workspace / Team Pill
            HStack(spacing: 5) {
                Image(systemName: "building.2")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Text(workspaceTitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .glassEffect(.regular, in: .capsule)
            
            Spacer()
            
            // Adaptive Polling Interval Pill
            HStack(spacing: 4) {
                Image(systemName: viewModel.hasActiveBuilds ? "bolt.fill" : "timer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(viewModel.hasActiveBuilds ? .blue : .secondary)
                Text(pollingStatusText)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(viewModel.hasActiveBuilds ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .glassEffect(
                viewModel.hasActiveBuilds
                    ? .regular.tint(Color.blue.opacity(0.14))
                    : .regular,
                in: .capsule
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private var workspaceTitle: String {
        if let team = viewModel.effectiveTeamSlug, !team.isEmpty {
            return team
        }
        if let user = viewModel.currentUsername, !user.isEmpty {
            return user
        }
        return "Personal Workspace"
    }
    
    private var pollingStatusText: String {
        if viewModel.hasActiveBuilds {
            return "10s Active"
        }
        return "\(Int(viewModel.currentPollingInterval))s"
    }
    
    private func triggerManualRefresh() {
        isSpinningRefresh = true
        Task {
            await viewModel.fetchAllData(isManual: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isSpinningRefresh = false
            }
        }
    }
    
    private func openWebDashboard() {
        let targetURL: URL
        if let team = viewModel.effectiveTeamSlug, !team.isEmpty {
            targetURL = URL(string: "https://vercel.com/\(team)")!
        } else {
            targetURL = URL(string: "https://vercel.com")!
        }
        VercelDeepLinkHelper.openInBrowser(targetURL)
    }
    
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        showingSettingsSheet = true
    }
}
