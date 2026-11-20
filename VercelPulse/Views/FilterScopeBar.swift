import SwiftUI

/// Scope filter options for deployment list.
public enum FilterScope: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case production = "Production"
    case preview = "Preview"
    
    public var id: String { rawValue }
    
    public var title: String { rawValue }
    
    public var shortTitle: String {
        switch self {
        case .all: return "All"
        case .production: return "Prod"
        case .preview: return "Prev"
        }
    }
    
    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .production: return "bolt.fill"
        case .preview: return "eye.fill"
        }
    }
}

/// Liquid Glass segmented pill bar for filtering deployments by scope.
public struct FilterScopeBar: View {
    @Binding public var selectedScope: FilterScope
    public var allCount: Int
    public var prodCount: Int
    public var prevCount: Int
    
    @Namespace private var selectionNamespace
    
    public init(
        selectedScope: Binding<FilterScope>,
        allCount: Int = 0,
        prodCount: Int = 0,
        prevCount: Int = 0
    ) {
        self._selectedScope = selectedScope
        self.allCount = allCount
        self.prodCount = prodCount
        self.prevCount = prevCount
    }
    
    public var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(FilterScope.allCases) { scope in
                    scopePill(for: scope)
                }
            }
            .padding(3)
            .glassEffect(.regular, in: .capsule)
        }
    }
    
    @ViewBuilder
    private func scopePill(for scope: FilterScope) -> some View {
        let isSelected = selectedScope == scope
        let count = countForScope(scope)
        
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedScope = scope
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: scope.iconName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(iconColor(for: scope, isSelected: isSelected))
                
                Text(scope.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        Capsule()
                            .fill(badgeBackgroundColor(for: scope, isSelected: isSelected))
                    )
                    .foregroundStyle(badgeTextColor(for: scope, isSelected: isSelected))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5.5)
            .padding(.horizontal, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(selectionTint(for: scope)).interactive(),
                            in: .capsule
                        )
                        .glassEffectID("active-scope-pill", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func countForScope(_ scope: FilterScope) -> Int {
        switch scope {
        case .all: return allCount
        case .production: return prodCount
        case .preview: return prevCount
        }
    }
    
    private func selectionTint(for scope: FilterScope) -> Color {
        switch scope {
        case .all: return Color.primary.opacity(0.08)
        case .production: return Color.purple.opacity(0.18)
        case .preview: return Color.blue.opacity(0.18)
        }
    }
    
    private func iconColor(for scope: FilterScope, isSelected: Bool) -> Color {
        guard isSelected else { return .secondary }
        switch scope {
        case .all: return .primary
        case .production: return .purple
        case .preview: return .blue
        }
    }
    
    private func badgeBackgroundColor(for scope: FilterScope, isSelected: Bool) -> Color {
        if isSelected {
            switch scope {
            case .all: return Color.primary.opacity(0.12)
            case .production: return Color.purple.opacity(0.22)
            case .preview: return Color.blue.opacity(0.22)
            }
        } else {
            return Color.primary.opacity(0.07)
        }
    }
    
    private func badgeTextColor(for scope: FilterScope, isSelected: Bool) -> Color {
        if isSelected {
            switch scope {
            case .all: return .primary
            case .production: return .purple
            case .preview: return .blue
            }
        } else {
            return .secondary
        }
    }
}
