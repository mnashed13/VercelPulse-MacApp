import SwiftUI
import AppKit

@main
struct VercelPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: DashboardViewModel
    
    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--demo") {
            let vm = DashboardViewModel(autoStart: false)
            Self.populateDemoData(into: vm, authenticated: true)
            _viewModel = StateObject(wrappedValue: vm)
            AppDelegate.demoViewModel = vm
            AppDelegate.demoMode = .dashboard
        } else if args.contains("--demo-onboarding") {
            let vm = DashboardViewModel(autoStart: false)
            Self.populateDemoData(into: vm, authenticated: false)
            _viewModel = StateObject(wrappedValue: vm)
            AppDelegate.demoViewModel = vm
            AppDelegate.demoMode = .onboarding
        } else if args.contains("--demo-settings") {
            let vm = DashboardViewModel(autoStart: false)
            Self.populateDemoData(into: vm, authenticated: true)
            _viewModel = StateObject(wrappedValue: vm)
            AppDelegate.demoViewModel = vm
            AppDelegate.demoMode = .settings
        } else {
            _viewModel = StateObject(wrappedValue: DashboardViewModel())
        }
    }
    
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
            Image(nsImage: VercelMenuBarIcon.menuBarImage())
                .accessibilityLabel("VercelPulse")
                .accessibilityValue(viewModel.pulseStatusText)
        }
        .menuBarExtraStyle(.window)
    }
    
    @MainActor
    private static func populateDemoData(into vm: DashboardViewModel, authenticated: Bool) {
        vm.isAuthenticated = authenticated
        guard authenticated else {
            vm.deployments = []
            vm.filteredDeployments = []
            vm.usage = nil
            return
        }
        
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        vm.currentToken = OAuthToken(
            accessToken: "demo_token",
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: 3600,
            teamId: "acme-engineering",
            userId: "michael"
        )
        
        let d1 = Deployment(
            uid: "dpl_demo_building",
            name: "vercel-pulse-web",
            url: "vercel-pulse-web-git-liquid-glass.vercel.app",
            state: "BUILDING",
            readyState: .building,
            target: "production",
            inspectorUrl: "https://vercel.com/acme-engineering/vercel-pulse-web/dpl_demo_building",
            created: nowMs - 45_000,
            ready: nil,
            buildingAt: nowMs - 38_000,
            creator: DeploymentCreator(uid: "u1", username: "michael"),
            meta: DeploymentMeta(
                githubCommitMessage: "Adopt macOS Liquid Glass design system and official Vercel mark",
                githubCommitRef: "feat/liquid-glass-ui",
                githubCommitAuthorName: "Michael Nashed",
                githubCommitSha: "a94f3c1e8b20",
                githubCommitOrg: "mnashed13",
                githubCommitRepo: "vercel-pulse-web"
            )
        )
        
        let d2 = Deployment(
            uid: "dpl_demo_ready_prod",
            name: "next-commerce-edge",
            url: "next-commerce-edge.vercel.app",
            state: "READY",
            readyState: .ready,
            target: "production",
            inspectorUrl: "https://vercel.com/acme-engineering/next-commerce-edge/dpl_demo_ready_prod",
            created: nowMs - 14 * 60_000,
            ready: nowMs - 14 * 60_000,
            buildingAt: nowMs - 15 * 60_000,
            creator: DeploymentCreator(uid: "u1", username: "michael"),
            meta: DeploymentMeta(
                githubCommitMessage: "feat(checkout): enable Edge Config dynamic pricing & streaming SSR",
                githubCommitRef: "main",
                githubCommitAuthorName: "Michael Nashed",
                githubCommitSha: "7c21d8b4019a",
                githubCommitOrg: "mnashed13",
                githubCommitRepo: "next-commerce-edge"
            )
        )
        
        let d3 = Deployment(
            uid: "dpl_demo_preview_ready",
            name: "ai-sdk-playground",
            url: "ai-sdk-playground-pr-42.vercel.app",
            state: "READY",
            readyState: .ready,
            target: "preview",
            inspectorUrl: "https://vercel.com/acme-engineering/ai-sdk-playground/dpl_demo_preview_ready",
            created: nowMs - 52 * 60_000,
            ready: nowMs - 52 * 60_000,
            buildingAt: nowMs - 53 * 60_000,
            creator: DeploymentCreator(uid: "u2", username: "sarah"),
            meta: DeploymentMeta(
                githubCommitMessage: "Add structured tool-calling preview cards and latency telemetry",
                githubCommitRef: "pr/streaming-tools",
                githubCommitAuthorName: "Sarah Lin",
                githubCommitSha: "f3e091a77c12",
                githubCommitOrg: "mnashed13",
                githubCommitRepo: "ai-sdk-playground"
            )
        )
        
        let d4 = Deployment(
            uid: "dpl_demo_error",
            name: "docs-portal",
            url: "docs-portal-git-mdx-v3.vercel.app",
            state: "ERROR",
            readyState: .error,
            target: "preview",
            inspectorUrl: "https://vercel.com/acme-engineering/docs-portal/dpl_demo_error",
            created: nowMs - 2 * 3600_000,
            ready: nil,
            buildingAt: nowMs - 2 * 3600_000 - 25_000,
            creator: DeploymentCreator(uid: "u3", username: "alex"),
            meta: DeploymentMeta(
                githubCommitMessage: "Upgrade MDX compiler to v3 and regenerate API reference pages",
                githubCommitRef: "chore/mdx-upgrade",
                githubCommitAuthorName: "Alex Rivera",
                githubCommitSha: "4b88e2d190f3",
                githubCommitOrg: "mnashed13",
                githubCommitRepo: "docs-portal"
            )
        )
        
        vm.deployments = [d1, d2, d3, d4]
        vm.updateFilteredDeployments()
        vm.currentPollingInterval = 10.0
        vm.usage = Usage(metrics: [
            "fast_data_transfer": Usage.MetricDetail(limit: 100_000_000, usage: 42_800_000),
            "edge_requests": Usage.MetricDetail(limit: 1_000_000, usage: 810_000),
            "function_invocations": Usage.MetricDetail(limit: 1_000_000, usage: 245_000)
        ])
    }
}

/// Optional delegate used solely when launched with `--demo*` flags to display a floating
/// Liquid Glass preview window for local verification.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    enum DemoMode {
        case dashboard
        case onboarding
        case settings
    }
    
    static var demoMode: DemoMode?
    static var demoViewModel: DashboardViewModel?
    private var previewWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let mode = Self.demoMode, let vm = Self.demoViewModel else { return }
        
        let rootView: AnyView
        let size: NSSize
        switch mode {
        case .dashboard, .onboarding:
            rootView = AnyView(
                PopoverView(viewModel: vm)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            size = NSSize(width: 392, height: 556)
        case .settings:
            rootView = AnyView(
                SettingsView(viewModel: vm)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            size = NSSize(width: 470, height: 550)
        }
        
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.borderless, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.setContentSize(size)
        if let primary = NSScreen.screens.first {
            let vf = primary.visibleFrame
            let origin = NSPoint(
                x: vf.midX - size.width / 2,
                y: vf.midY - size.height / 2
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        self.previewWindow = window
        
        NSApp.activate(ignoringOtherApps: true)
    }
}
