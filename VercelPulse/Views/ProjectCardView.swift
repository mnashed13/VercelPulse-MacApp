import SwiftUI

/// Backwards compatibility view wrapping DeploymentCardView.
public struct ProjectCardView: View {
    public let deployment: Deployment
    public let projects: [Project]
    
    public init(deployment: Deployment, projects: [Project] = []) {
        self.deployment = deployment
        self.projects = projects
    }
    
    public var project: Project? {
        projects.first { $0.name == deployment.name }
    }
    
    public var body: some View {
        DeploymentCardView(deployment: deployment)
    }
}
