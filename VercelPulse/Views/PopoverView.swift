import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("VercelPulse")
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    Task { await viewModel.fetchAllData() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        if !viewModel.deployments.isEmpty {
                            Text("Recent Deployments")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(viewModel.deployments) { deployment in
                                ProjectCardView(deployment: deployment, projects: viewModel.projects)
                                    .padding(.horizontal)
                            }
                        }
                        
                        if let usage = viewModel.usage {
                            Divider()
                            Text("Usage")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            UsageMetricsView(usage: usage)
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                        } else {
                             // No usage fallback
                            Divider()
                            Text("Usage metrics not available for this account.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
            }
        }
        .frame(width: 350, height: 500)
        .onAppear {
            if viewModel.showSettings {
                // If it wants to show settings immediately, open window.
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
                viewModel.showSettings = false
            }
        }
        .onChange(of: viewModel.showSettings) { newValue in
            if newValue {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
                viewModel.showSettings = false
            }
        }
    }
}
