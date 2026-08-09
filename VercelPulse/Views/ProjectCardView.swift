import SwiftUI

struct ProjectCardView: View {
    let deployment: Deployment
    let projects: [Project]
    
    var project: Project? {
        projects.first { $0.name == deployment.name }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(deployment.name)
                    .font(.headline)
                
                Spacer()
                
                Text(deployment.state)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            if let commit = deployment.meta?.githubCommitMessage {
                Text(commit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("Manual deployment")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(timeAgo(from: deployment.created))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if let url = URL(string: "https://\(deployment.url)") {
                    Link(destination: url) {
                        Text("View")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    var statusColor: Color {
        switch deployment.state {
        case "READY": return .green
        case "BUILDING": return .blue
        case "ERROR": return .red
        case "CANCELED": return .gray
        default: return .gray
        }
    }
    
    func timeAgo(from msTimestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(msTimestamp) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
