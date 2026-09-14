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

/// Modern segmented pill bar for filtering deployments by scope.
public struct FilterScopeBar: View {
    @Binding public var selectedScope: FilterScope
    public var allCount: Int
    public var prodCount: Int
    public var prevCount: Int
    
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
        HStack(spacing: 6) {
            ForEach(FilterScope.allCases) { scope in
                scopePill(for: scope)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func scopePill(for scope: FilterScope) -> some View {
        let isSelected = selectedScope == scope
        let count = countForScope(scope)
        
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedScope = scope
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: scope.iconName)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(iconColor(for: scope, isSelected: isSelected))
                
                Text(scope.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text("\(count)")
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(badgeBackgroundColor(for: scope, isSelected: isSelected))
                    )
                    .foregroundColor(badgeTextColor(for: scope, isSelected: isSelected))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(NSColor.selectedControlColor).opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
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
            case .production: return Color.purple.opacity(0.2)
            case .preview: return Color.blue.opacity(0.2)
            }
        } else {
            return Color.primary.opacity(0.06)
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
