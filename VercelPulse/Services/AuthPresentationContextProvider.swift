import Foundation
import AuthenticationServices
import AppKit

/// Provides an ASPresentationAnchor (NSWindow) for ASWebAuthenticationSession with multi-tier fallback for LSUIElement menu bar apps.
public final class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    public static let shared = AuthPresentationContextProvider()
    
    private var fallbackWindow: NSWindow?
    private let lock = NSLock()
    
    override public init() {
        super.init()
    }
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        lock.lock()
        defer { lock.unlock() }
        
        // Tier 1: Look for active keyWindow
        if let keyWindow = NSApplication.shared.keyWindow, keyWindow.isVisible {
            return keyWindow
        }
        
        // Tier 2: Look for any visible window capable of becoming key (e.g. popover hosting window or settings window)
        if let candidate = NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
            return candidate
        }
        
        // Tier 3: Look for any visible window
        if let visibleWindow = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return visibleWindow
        }
        
        // Tier 4: Headless fallback window (prevents crashes when invoked from menu bar extra without key window)
        if let existing = fallbackWindow, existing.isVisible {
            return existing
        }
        
        let dummy = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        dummy.isReleasedWhenClosed = false
        dummy.isOpaque = false
        dummy.backgroundColor = .clear
        dummy.orderFrontRegardless()
        
        self.fallbackWindow = dummy
        return dummy
    }
    
    public func cleanUpFallbackWindow() {
        lock.lock()
        defer { lock.unlock() }
        fallbackWindow?.orderOut(nil)
        fallbackWindow = nil
    }
}
