import SwiftUI

/// Design-system modifiers implementing macOS Liquid Glass surfaces, specular rim highlights,
/// and interactive glass controls consistently across VercelPulse.
public extension View {
    
    /// Applies a translucent Liquid Glass content card surface with a subtle specular top-leading rim.
    /// Ideal for scrollable content cards (deployments, usage metrics, settings groups) where
    /// clarity and legibility over vibrant wallpapers are paramount.
    func liquidGlassCard(
        cornerRadius: CGFloat = 16,
        tint: Color? = nil,
        borderColor: Color = Color.white.opacity(0.22),
        borderWidth: CGFloat = 0.8,
        isHovered: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                ZStack {
                    shape
                        .fill(.thinMaterial)
                    
                    // Subtle top-leading specular sheen
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.16 : 0.10),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if let tint {
                        shape
                            .fill(tint.opacity(isHovered ? 0.11 : 0.06))
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                borderColor,
                                borderColor.opacity(0.35),
                                Color.primary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            }
            .shadow(color: Color.black.opacity(isHovered ? 0.14 : 0.08), radius: isHovered ? 10 : 6, x: 0, y: isHovered ? 4 : 2)
    }
    
    /// Applies a native interactive Liquid Glass pill or capsule control using macOS 26+ `.glassEffect`.
    @ViewBuilder
    func liquidGlassControl(
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        if let tint {
            if interactive {
                self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular.tint(tint), in: .capsule)
            }
        } else {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular, in: .capsule)
            }
        }
    }
    
    /// Applies a native interactive Liquid Glass circular icon button using macOS 26+ `.glassEffect`.
    @ViewBuilder
    func liquidGlassCircleControl(
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        if let tint {
            if interactive {
                self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
            } else {
                self.glassEffect(.regular.tint(tint), in: .circle)
            }
        } else {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .circle)
            } else {
                self.glassEffect(.regular, in: .circle)
            }
        }
    }
    
}

/// Soft hairline divider tailored for translucent Liquid Glass surfaces.
public struct LiquidGlassDivider: View {
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.02),
                        Color.primary.opacity(0.10),
                        Color.primary.opacity(0.02)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.75)
    }
}
