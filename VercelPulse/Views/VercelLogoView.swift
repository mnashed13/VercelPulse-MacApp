import SwiftUI
import AppKit

/// Official Vercel equilateral triangle logo geometry (aspect ratio 75.0548 : 65).
/// Renders sharp, crisp vertices matching the official Vercel brand mark.
public struct VercelLogoShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Crisp vector SwiftUI view of the official Vercel logo.
public struct VercelLogoView: View {
    public var size: CGFloat
    public var color: Color
    
    /// Official Vercel triangle width-to-height aspect ratio (`75.0548 / 65.0`).
    public static let aspectRatio: CGFloat = 75.0548 / 65.0
    
    public init(size: CGFloat = 14, color: Color = .primary) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        VercelLogoShape()
            .fill(color)
            .frame(width: size * Self.aspectRatio, height: size)
            .accessibilityHidden(true)
    }
}

/// Generates a pixel-aligned HiDPI template `NSImage` of the official Vercel logo
/// for native macOS menu bar rendering with full Liquid Glass vibrancy.
public enum VercelMenuBarIcon {
    /// Returns a crisp, template-mode `NSImage` sized for the macOS menu bar (18x18 pt canvas).
    public static func menuBarImage(canvasSize: CGFloat = 18, triangleHeight: CGFloat = 12.5) -> NSImage {
        let size = NSSize(width: canvasSize, height: canvasSize)
        let image = NSImage(size: size, flipped: false) { bounds in
            let triHeight = triangleHeight
            let triWidth = triHeight * VercelLogoView.aspectRatio
            let originX = (bounds.width - triWidth) / 2.0
            let originY = (bounds.height - triHeight) / 2.0
            
            let path = NSBezierPath()
            // Top vertex (AppKit coordinates have origin at bottom-left)
            path.move(to: NSPoint(x: bounds.midX, y: originY + triHeight))
            // Bottom-right vertex
            path.line(to: NSPoint(x: originX + triWidth, y: originY))
            // Bottom-left vertex
            path.line(to: NSPoint(x: originX, y: originY))
            path.close()
            
            NSColor.labelColor.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
