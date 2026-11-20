import SwiftUI

/// Liquid Glass onboarding screen presented when the user is unauthenticated.
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
    
    public var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)
            
            // Official Vercel Logo in Liquid Glass Emblem
            VStack(spacing: 9) {
                ZStack {
                    VercelLogoView(size: 24, color: .primary)
                        .offset(y: -1.5)
                }
                .frame(width: 60, height: 60)
                .glassEffect(.regular, in: .circle)
                .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 4)
                
                Text("VercelPulse")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Real-time Vercel deployment tracking right from your macOS menu bar.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Feature Highlights Glass Card
            VStack(alignment: .leading, spacing: 11) {
                featureRow(
                    icon: "bolt.fill",
                    iconColor: .orange,
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
                    subtitle: "OAuth 2.0 & native Keychain encryption."
                )
            }
            .padding(14)
            .liquidGlassCard(cornerRadius: 16)
            .padding(.horizontal, 16)
            
            // Quick Connect Glass Card (Instant PAT)
            VStack(spacing: 10) {
                HStack {
                    Text("Connect Account")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        if let url = URL(string: "https://vercel.com/account/tokens") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text("Get Token")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 7) {
                    SecureField("Paste Vercel Token...", text: $inlineToken)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6.5)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                        )
                    
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
                    .buttonStyle(.glassProminent)
                    .disabled(inlineToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: onSignIn) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("OAuth Sign In")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .liquidGlassControl()
                        
                        Button(action: onOpenSettings) {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("More Settings")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .liquidGlassControl()
                    }
                }
                .padding(.top, 2)
            }
            .padding(14)
            .liquidGlassCard(cornerRadius: 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 28, height: 28)
            .glassEffect(.regular.tint(iconColor.opacity(0.18)), in: .circle)
            
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
