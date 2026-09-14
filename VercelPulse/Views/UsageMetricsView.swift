import SwiftUI

/// Displays Vercel account and workspace usage metrics.
public struct UsageMetricsView: View {
    public let usage: Usage
    
    public init(usage: Usage) {
        self.usage = usage
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            if let metrics = usage.metrics, !metrics.isEmpty {
                ForEach(Array(metrics.keys.sorted()), id: \.self) { key in
                    if let detail = metrics[key], let current = detail.usage, let limit = detail.limit {
                        MetricRow(title: formatKey(key), usage: current, limit: limit)
                    }
                }
            } else {
                Text("No detailed usage metrics available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func formatKey(_ key: String) -> String {
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// A single row representing a metric with progress bar and formatted limits.
public struct MetricRow: View {
    public let title: String
    public let usage: Int
    public let limit: Int
    
    public init(title: String, usage: Int, limit: Int) {
        self.title = title
        self.usage = usage
        self.limit = limit
    }
    
    private var progressRatio: Double {
        guard limit > 0 else { return 0.0 }
        return min(max(Double(usage) / Double(limit), 0.0), 1.0)
    }
    
    private var progressColor: Color {
        if progressRatio >= 1.0 {
            return .red
        } else if progressRatio >= 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(formatNumber(usage)) / \(formatNumber(limit))")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(progressRatio), height: 5)
                }
            }
            .frame(height: 5)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000_000 {
            return String(format: "%.1fB", Double(number) / 1_000_000_000.0)
        } else if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000.0)
        } else {
            return "\(number)"
        }
    }
}
