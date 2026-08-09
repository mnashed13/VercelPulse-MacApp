import SwiftUI

@main
struct VercelPulseApp: App {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some Scene {
        MenuBarExtra("VercelPulse", systemImage: "triangle.fill") {
            PopoverView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
        
        Window("Settings", id: "settings") {
            SettingsView(viewModel: viewModel)
        }
    }
}
