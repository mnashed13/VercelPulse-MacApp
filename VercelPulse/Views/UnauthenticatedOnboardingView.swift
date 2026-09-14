import SwiftUI

/// Onboarding screen presented when the user is unauthenticated.
public struct UnauthenticatedOnboardingView: View {
    public var isAuthenticating: Bool
    public var onSignIn: () -> Void
    public var onOpenSettings: () -> Void
    public var onSavePAT: ((String) -> Void)?
    
    public init(
        isAuthenticating: Bool = false,
        onSignIn: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onSavePAT: ((String) -> Void)? = nil
    ) {
        self.isAuthenticating = isAuthenticating
        self.onSignIn = onSignIn
        self.onOpenSettings = onOpenSettings
        self.onSavePAT = onSavePAT
    }
    
    @State private var inlineToken: String = ""
    @State private var showOAuthInstructions = false
    
    public var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)
            
            // App Logo & Title
            VStack(spacing: 6) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("VercelPulse")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Real-time Vercel deployment tracking right from your macOS menu bar.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            // Feature Highlights
            VStack(alignment: .leading, spacing: 10) {
                featureRow(
                    icon: "bolt.fill",
                    iconColor: .yellow,
                    title: "Live Build Updates",
                    subtitle: "Adaptive 10s polling when builds are active."
                )
                
                featureRow(
                    icon: "arrow.triangle.branch",
                    iconColor: .purple,
                    title: "1-Click Deep Links",
                    subtitle: "Jump straight to Vercel Inspector or Preview URLs."
                )
                
                featureRow(
                    icon: "lock.shield.fill",
                    iconColor: .blue,
                    title: "Secure Authentication",
                    subtitle: "OAuth 2.0 & Keychain encryption."
                )
            }
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Quick Connect Section (Instant PAT)
            VStack(spacing: 8) {
                HStack {
                    Text("Connect Account")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        if let url = URL(string: "https://vercel.com/account/tokens") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 2) {
                            Text("Get Token")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 6) {
                    SecureField("Paste Vercel Token...", text: $inlineToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Button(action: {
                        let clean = inlineToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            if let onSavePAT = onSavePAT {
                                onSavePAT(clean)
                            } else {
                                try? VercelOAuthService.shared.savePersonalAccessToken(clean, teamId: nil)
                            }
                        }
                    }) {
                        Text("Connect")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inlineToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                HStack(spacing: 12) {
                    Button(action: onSignIn) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                            Text("OAuth Sign In")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Button(action: onOpenSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("More Settings")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}
