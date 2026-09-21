import SwiftUI

/// Main macOS Menu Bar popover view housing the deployment dashboard, filter controls,
/// live pulse indicator, error alerts, and usage analytics.
public struct PopoverView: View {
    @ObservedObject public var viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    
    @State private var isSpinningRefresh = false
    @State private var showingSettingsSheet = false
    @State private var isRefreshHovered = false
    @State private var isDashboardHovered = false
    @State private var isGearHovered = false
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header & Toolbar
            headerView
            
            Divider()
            
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
            
            Divider()
            
            // MARK: - Footer Status Bar
            footerView
        }
        .frame(width: 360, height: 510)
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    // MARK: - Header & Toolbar
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // Logo, Title & Status Indicator
            HStack(spacing: 6) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("VercelPulse")
                    .font(.system(size: 13, weight: .bold))
                
                pulseSyncDot
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 2) {
                // Manual Refresh Button
                Button(action: {
                    triggerManualRefresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .symbolEffect(.rotate, isActive: isSpinningRefresh || viewModel.isLoading)
                        .foregroundColor(viewModel.isLoading ? .secondary.opacity(0.4) : (isRefreshHovered ? .primary : .secondary))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isRefreshHovered && !viewModel.isLoading ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .keyboardShortcut("r", modifiers: .command)
                .onHover { isRefreshHovered = $0 }
                .help("Refresh Deployments (⌘R)")
                
                // Web Dashboard Quick Link
                Button(action: {
                    openWebDashboard()
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDashboardHovered ? .primary : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isDashboardHovered ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o", modifiers: .command)
                .onHover { isDashboardHovered = $0 }
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isGearHovered ? .primary : .secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isGearHovered ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .onHover { isGearHovered = $0 }
                .help("Settings & Options")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Pulse Sync Indicator
    
    @ViewBuilder
    private var pulseSyncDot: some View {
        HStack(spacing: 4) {
            if viewModel.deployments.isEmpty && viewModel.isLoading {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                Text("Syncing...")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            } else if viewModel.errorMessage != nil && viewModel.deployments.isEmpty {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("Error")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            } else {
                Circle()
                    .fill(viewModel.pulseStatusColor)
                    .frame(width: 6, height: 6)
                Text(viewModel.pulseStatusText)
                    .font(.system(size: 10, weight: viewModel.hasActiveBuilds ? .medium : .regular))
                    .foregroundColor(viewModel.hasActiveBuilds || viewModel.pulseStatusColor == Color.red ? viewModel.pulseStatusColor : .secondary)
            }
        }
    }
    
    // MARK: - Authenticated Dashboard
    
    private var authenticatedDashboardView: some View {
        VStack(spacing: 8) {
            // Scope Filter Bar
            FilterScopeBar(
                selectedScope: $viewModel.selectedScope,
                allCount: viewModel.allCount,
                prodCount: viewModel.productionCount,
                prevCount: viewModel.previewCount
            )
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
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
                .padding(.horizontal, 10)
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
                .padding(.horizontal, 10)
            }
            
            // Deployment List or Empty/Loading States
            if viewModel.isLoading && viewModel.deployments.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Fetching deployments...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredDeployments.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
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
                            VStack(alignment: .leading, spacing: 6) {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text("Account Usage")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                
                                UsageMetricsView(usage: usage)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "shippingbox")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No \(viewModel.selectedScope.title.lowercased()) deployments")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Deployments pushed to Vercel will appear here automatically.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {
                triggerManualRefresh()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Workspace / Team Indicator
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(workspaceTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Polling interval badge
            HStack(spacing: 3) {
                Image(systemName: "timer")
                    .font(.system(size: 9))
                Text(pollingStatusText)
                    .font(.system(size: 9, design: .monospaced))
            }
            .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private var workspaceTitle: String {
        if let team = viewModel.effectiveTeamSlug, !team.isEmpty {
            return team
        }
        if let user = viewModel.currentUsername, !user.isEmpty {
            return "User: \(user)"
        }
        return "Personal Workspace"
    }
    
    private var pollingStatusText: String {
        if viewModel.hasActiveBuilds {
            return "10s (Active)"
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
