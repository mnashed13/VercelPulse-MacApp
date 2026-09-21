import SwiftUI

@main
struct VercelPulseApp: App {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
                .onOpenURL { url in
                    Task {
                        do {
                            _ = try await VercelOAuthService.shared.handleCallback(url: url)
                            await MainActor.run {
                                viewModel.checkAuthStatus()
                                if viewModel.isAuthenticated {
                                    viewModel.startTimer()
                                    Task {
                                        await viewModel.fetchAllData()
                                    }
                                }
                            }
                        } catch {
                            print("Failed to handle incoming URL: \(error.localizedDescription)")
                        }
                    }
                }
        } label: {
            Image(systemName: viewModel.menuBarSystemImage)
                .accessibilityLabel("VercelPulse")
        }
        .menuBarExtraStyle(.window)
    }
}
