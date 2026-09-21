import SwiftUI

/// Settings view providing authentication management, Personal Access Token configuration,
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
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text("VercelPulse Settings")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
            
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: - Connection Status Section
                    connectionStatusSection
                    
                    Divider()
                    
                    // MARK: - Manual Personal Access Token Section
                    patSection
                    
                    Divider()
                    
                    // MARK: - Workspace & Team ID Section
                    workspaceSection
                    
                    Divider()
                    
                    // MARK: - Advanced OAuth 2.0 Credentials Section
                    oauthCredentialsSection
                    
                    Divider()
                    
                    // MARK: - Polling Information Section
                    pollingSection
                }
                .padding(16)
            }
            
            Divider()
            
            // Footer Action Buttons
            HStack {
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
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(role: .destructive, action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text("Quit App")
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit VercelPulse (⌘Q)")
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 460, height: 520)
        .onAppear {
            loadInitialSettings()
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Status")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            
            if viewModel.isAuthenticated {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Connected to Vercel")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    if let userId = viewModel.currentToken?.userId {
                        Text("User: \(userId)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text("Not Connected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        
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
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAuthenticating)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    @ViewBuilder
    private var patSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Personal Access Token (Recommended)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            Text("Create a token in Vercel Account Settings → Tokens and paste it below for instant connection.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            SecureField("Enter Vercel Token (e.g. vc_tok_...)", text: $token)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }
    
    @ViewBuilder
    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Team Workspace Scope (Optional)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Specify a Vercel Team ID or Slug to scope deployments and usage metrics to a team workspace.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            TextField("e.g. team_123456789 or my-team-slug", text: $teamId)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }
    
    @ViewBuilder
    private var oauthCredentialsSection: some View {
        DisclosureGroup(isExpanded: $showOAuthDetails) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Configure custom OAuth 2.0 Integration Client ID & Secret if running your own Vercel Integration.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Client ID")
                        .font(.system(size: 10, weight: .semibold))
                    TextField("e.g. oac_xxxxxxxx", text: $oauthClientId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Client Secret (Optional)")
                        .font(.system(size: 10, weight: .semibold))
                    SecureField("e.g. sec_xxxxxxxx", text: $oauthClientSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .padding(.top, 4)
        } label: {
            Text("Custom OAuth 2.0 App Settings (Advanced)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adaptive Polling Engine")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Idle Polling")
                        .font(.system(size: 11, weight: .semibold))
                    Text("60 seconds")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Build Polling")
                        .font(.system(size: 11, weight: .semibold))
                    Text("10 seconds (Automatic)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
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
