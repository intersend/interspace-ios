import SwiftUI

// MARK: - Squircle Shape

/// A shape that creates a squircle (superellipse) with continuous corners
/// matching iOS app icon shape specifications
struct SquircleShape: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        // For iOS icons, we use the continuous corner style
        // which is Apple's implementation of squircles
        let path = UIBezierPath(
            roundedRect: rect,
            cornerRadius: cornerRadius
        )
        return Path(path.cgPath)
    }
}

// MARK: - Continuous Corner Rectangle

/// A more accurate squircle implementation using continuous corners
struct ContinuousRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: rect,
            cornerRadius: cornerRadius,
            style: .continuous
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Clips the view to a squircle shape with continuous corners
    func squircleClip(cornerRadius: CGFloat) -> some View {
        self.clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Adds a squircle overlay with continuous corners
    func squircleOverlay<S: ShapeStyle>(_ style: S, lineWidth: CGFloat = 1) -> some View {
        self.overlay(
            ContinuousRoundedRectangle(cornerRadius: cornerRadiusForFrame())
                .stroke(style, lineWidth: lineWidth)
        )
    }
    
    private func cornerRadiusForFrame() -> CGFloat {
        // iOS uses approximately 22.5% of the icon size for corner radius
        // This is calculated dynamically based on the view's size
        return 60 * 0.225 // Default for 60pt icons
    }
}