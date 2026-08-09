import SwiftUI

struct UsageMetricsView: View {
    let usage: Usage
    
    var body: some View {
        VStack(spacing: 12) {
            if let metrics = usage.metrics, !metrics.isEmpty {
                ForEach(Array(metrics.keys.sorted()), id: \.self) { key in
                    if let detail = metrics[key], let current = detail.usage, let limit = detail.limit {
                        MetricRow(title: formatKey(key), usage: current, limit: limit)
                    }
                }
            } else {
                Text("No detailed metrics found.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    func formatKey(_ key: String) -> String {
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct MetricRow: View {
    let title: String
    let usage: Int
    let limit: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(formatNumber(usage)) / \(formatNumber(limit))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: Double(usage), total: Double(limit > 0 ? limit : 1))
                .progressViewStyle(.linear)
                .tint(usage >= limit ? .red : .blue)
        }
    }
    
    func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000.0)
        } else {
            return "\(number)"
        }
    }
}
