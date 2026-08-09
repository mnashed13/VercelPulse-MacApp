import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var token: String = ""
    @State private var teamId: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Vercel Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Access Token")
                    .font(.caption)
                SecureField("Enter Token...", text: $token)
                    .textFieldStyle(.roundedBorder)
                
                Text("Create a token in Vercel Dashboard -> Account Settings -> Tokens.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Team ID (Optional)")
                    .font(.caption)
                TextField("Enter Team ID...", text: $teamId)
                    .textFieldStyle(.roundedBorder)
                
                Text("Required only if you want to fetch resources for a specific team.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if viewModel.isAuthenticated {
                    Button("Logout") {
                        viewModel.logout()
                        token = ""
                        teamId = ""
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    if !token.isEmpty && token != "********" {
                        _ = KeychainManager.shared.saveToken(token)
                    }
                    UserDefaults.standard.set(teamId, forKey: "teamId")
                    
                    viewModel.checkAuthStatus()
                    if viewModel.isAuthenticated {
                        viewModel.startTimer()
                        Task {
                            await viewModel.fetchAllData()
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            teamId = UserDefaults.standard.string(forKey: "teamId") ?? ""
            if viewModel.isAuthenticated {
                token = "********" // Placeholder so they know it's set
            }
        }
    }
}
