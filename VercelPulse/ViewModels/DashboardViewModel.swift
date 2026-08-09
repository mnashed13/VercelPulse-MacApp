import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var deployments: [Deployment] = []
    @Published var usage: Usage?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var isAuthenticated = false
    @Published var showSettings = false
    
    private var timer: AnyCancellable?
    
    init() {
        checkAuthStatus()
        if isAuthenticated {
            startTimer()
            Task {
                await fetchAllData()
            }
        } else {
            showSettings = true
        }
    }
    
    func checkAuthStatus() {
        if let token = KeychainManager.shared.getToken(), !token.isEmpty {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }
    
    func startTimer() {
        timer?.cancel()
        // Refresh every 5 minutes (300 seconds)
        timer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isAuthenticated else { return }
                Task {
                    await self.fetchAllData()
                }
            }
    }
    
    func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    func fetchAllData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let projectsTask = VercelAPIService.shared.fetchProjects()
            async let deploymentsTask = VercelAPIService.shared.fetchDeployments()
            // We fetch usage independently because it might fail due to plan limits and we don't want to break the whole dashboard
            
            let fetchedProjects = try await projectsTask
            let fetchedDeployments = try await deploymentsTask
            
            self.projects = fetchedProjects
            self.deployments = fetchedDeployments
            
            do {
                self.usage = try await VercelAPIService.shared.fetchUsage()
            } catch {
                print("Usage fetch failed (this is common if not on Pro plan or new API): \(error)")
                self.usage = nil
            }
            
        } catch let error as VercelAPIService.APIError {
            self.errorMessage = error.localizedDescription
            if case .missingToken = error {
                self.isAuthenticated = false
                self.showSettings = true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        KeychainManager.shared.deleteToken()
        UserDefaults.standard.removeObject(forKey: "teamId")
        isAuthenticated = false
        projects = []
        deployments = []
        usage = nil
        stopTimer()
        showSettings = true
    }
}
