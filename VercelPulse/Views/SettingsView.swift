import SwiftUI

/// Liquid Glass settings view providing authentication management, Personal Access Token configuration,
/// team workspace scoping, and account logout actions.
public struct SettingsView: View {
    @ObservedObject public var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var token: String = ""
    @State private var teamId: String = ""
    @State private var oauthClientId: String = ""
    @State private var oauthClientSecret: String = ""
    @State private var showOAuthDetails = false
    @State private var showingSavedAlert = false
    @State private var selectedTab: SettingsTab = .account
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case account = "Account"
        case preferences = "Preferences"
        
        public var id: String { rawValue }
    }
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Liquid Glass Header
            HStack(spacing: 10) {
                ZStack {
                    VercelLogoView(size: 12, color: .primary)
                        .offset(y: -0.5)
                }
                .frame(width: 28, height: 28)
                .glassEffect(.regular, in: .circle)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("VercelPulse Settings")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Authentication, workspace scope & polling")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            LiquidGlassDivider()
                .padding(.horizontal, 14)
            
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    connectionStatusSection
                    patSection
                    workspaceSection
                    oauthCredentialsSection
                    pollingSection
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            
            LiquidGlassDivider()
                .padding(.horizontal, 14)
            
            // Footer Action Bar
            HStack(spacing: 8) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        if viewModel.isAuthenticated {
                            Button(role: .destructive, action: {
                                viewModel.logout()
                                token = ""
                                teamId = ""
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Log Out")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .liquidGlassControl(tint: Color.red.opacity(0.12))
                        }
                        
                        Button(role: .destructive, action: {
                            NSApplication.shared.terminate(nil)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "power")
                                Text("Quit")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .liquidGlassControl()
                        .help("Quit VercelPulse (⌘Q)")
                    }
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
                
                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 470, height: 550)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .onAppear {
            loadInitialSettings()
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Status")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            if viewModel.isAuthenticated {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green.opacity(0.6), radius: 3)
                    
                    Text("Connected to Vercel")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    if let userId = viewModel.currentToken?.userId {
                        Text("User: \(userId)")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: .orange.opacity(0.6), radius: 3)
                        
                        Text("Not Connected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                        
                        Spacer()
                    }
                    
                    Button(action: {
                        viewModel.startOAuthLogin()
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isAuthenticating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(viewModel.isAuthenticating ? "Connecting..." : "Sign in with Vercel (OAuth 2.0)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.isAuthenticating)
                }
            }
        }
        .padding(13)
        .liquidGlassCard(
            cornerRadius: 14,
            tint: viewModel.isAuthenticated ? .green : .orange,
            borderColor: (viewModel.isAuthenticated ? Color.green : Color.orange).opacity(0.28)
        )
    }
    
    @ViewBuilder
    private var patSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Personal Access Token (Recommended)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "https://vercel.com/account/tokens") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 3) {
                        Text("Create Token")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            Text("Create a token in Vercel Account Settings → Tokens and paste it below for instant connection.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            SecureField("Enter Vercel Token (e.g. vc_tok_...)", text: $token)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
        }
        .padding(13)
        .liquidGlassCard(cornerRadius: 14)
    }
    
    @ViewBuilder
    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Team Workspace Scope (Optional)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("Specify a Vercel Team ID or Slug to scope deployments and usage metrics to a team workspace.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            TextField("e.g. team_123456789 or my-team-slug", text: $teamId)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
        }
        .padding(13)
        .liquidGlassCard(cornerRadius: 14)
    }
    
    @ViewBuilder
    private var oauthCredentialsSection: some View {
        DisclosureGroup(isExpanded: $showOAuthDetails) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configure custom OAuth 2.0 Integration Client ID & Secret if running your own Vercel Integration.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Client ID")
                        .font(.system(size: 10, weight: .semibold))
                    TextField("e.g. oac_xxxxxxxx", text: $oauthClientId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Client Secret (Optional)")
                        .font(.system(size: 10, weight: .semibold))
                    SecureField("e.g. sec_xxxxxxxx", text: $oauthClientSecret)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Custom OAuth 2.0 App Settings (Advanced)")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .liquidGlassCard(cornerRadius: 14)
    }
    
    @ViewBuilder
    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adaptive Polling Engine")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Idle Polling")
                        .font(.system(size: 11, weight: .semibold))
                    Text("60 seconds")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 24)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Build Polling")
                        .font(.system(size: 11, weight: .semibold))
                    Text("10 seconds (Auto)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(13)
        .liquidGlassCard(cornerRadius: 14)
    }
    
    // MARK: - Actions
    
    private func loadInitialSettings() {
        teamId = UserDefaults.standard.string(forKey: "teamId") ?? viewModel.currentToken?.teamId ?? ""
        oauthClientId = UserDefaults.standard.string(forKey: "oauth_client_id") ?? ""
        oauthClientSecret = UserDefaults.standard.string(forKey: "oauth_client_secret") ?? ""
        if !oauthClientId.isEmpty {
            showOAuthDetails = true
        }
        if viewModel.isAuthenticated {
            token = "••••••••••••••••"
        }
    }
    
    private func saveSettings() {
        let cleanTeam = teamId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTeam.isEmpty {
            UserDefaults.standard.set(cleanTeam, forKey: "teamId")
        } else {
            UserDefaults.standard.removeObject(forKey: "teamId")
        }
        
        let cleanClientId = oauthClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanClientId.isEmpty {
            UserDefaults.standard.set(cleanClientId, forKey: "oauth_client_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "oauth_client_id")
        }
        
        let cleanClientSecret = oauthClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanClientSecret.isEmpty {
            UserDefaults.standard.set(cleanClientSecret, forKey: "oauth_client_secret")
        } else {
            UserDefaults.standard.removeObject(forKey: "oauth_client_secret")
        }
        
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanToken.isEmpty && !cleanToken.contains("•") {
            viewModel.savePAT(token: cleanToken, teamId: cleanTeam.isEmpty ? nil : cleanTeam)
        } else {
            // Re-fetch with new team settings
            viewModel.checkAuthStatus()
            if viewModel.isAuthenticated {
                Task {
                    await viewModel.fetchAllData(isManual: true)
                }
            }
        }
        
        dismiss()
    }
}
