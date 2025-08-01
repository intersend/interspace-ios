import SwiftUI
import UIKit

// MARK: - Liquid Glass Effect
@available(iOS 26.0, *)
struct LiquidGlassEffect: ViewModifier {
    let style: GlassStyle
    let cornerRadius: CGFloat
    let isInteractive: Bool
    
    @State private var refractionOffset: CGSize = .zero
    @State private var lensDistortion: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    init(style: GlassStyle = .regular, cornerRadius: CGFloat = 20, isInteractive: Bool = true) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassBackground(
                    style: style,
                    cornerRadius: cornerRadius,
                    refractionOffset: refractionOffset,
                    lensDistortion: lensDistortion
                )
            )
            .overlay(
                LiquidGlassOverlayEffect(
                    style: style,
                    cornerRadius: cornerRadius
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(InteractiveGlassModifier(isEnabled: isInteractive) { offset, pressure in
                updateGlassEffect(offset: offset, pressure: pressure)
            })
    }
    
    private func updateGlassEffect(offset: CGSize, pressure: CGFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            refractionOffset = CGSize(
                width: offset.width * 0.1,
                height: offset.height * 0.1
            )
            lensDistortion = pressure * 0.05
        }
    }
}

// MARK: - Glass Style
public enum GlassStyle {
    case ultraThin
    case thin
    case regular
    case thick
    case prominent
    
    var blurRadius: CGFloat {
        switch self {
        case .ultraThin: return 8
        case .thin: return 16
        case .regular: return 24
        case .thick: return 32
        case .prominent: return 40
        }
    }
    
    var saturation: Double {
        switch self {
        case .ultraThin: return 1.2
        case .thin: return 1.3
        case .regular: return 1.5
        case .thick: return 1.7
        case .prominent: return 2.0
        }
    }
    
    var opacity: Double {
        switch self {
        case .ultraThin: return 0.3
        case .thin: return 0.4
        case .regular: return 0.5
        case .thick: return 0.6
        case .prominent: return 0.7
        }
    }
}

// MARK: - Liquid Glass Background
@available(iOS 26.0, *)
struct LiquidGlassBackground: UIViewRepresentable {
    let style: GlassStyle
    let cornerRadius: CGFloat
    let refractionOffset: CGSize
    let lensDistortion: CGFloat
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        
        // Add custom backdrop filters for iOS 26
        if #available(iOS 26.0, *) {
            visualEffectView.addLiquidGlassFilters(style: style)
        }
        
        return visualEffectView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Update refraction and distortion
        if #available(iOS 26.0, *) {
            uiView.updateLiquidGlassEffect(
                refractionOffset: refractionOffset,
                lensDistortion: lensDistortion
            )
        }
    }
}

// MARK: - Liquid Glass Overlay Effect
@available(iOS 26.0, *)
struct LiquidGlassOverlayEffect: View {
    let style: GlassStyle
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Specular highlights layer
            LinearGradient(
                colors: [
                    Color.white.opacity(style.opacity * 0.3),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            
            // Edge lighting effect
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            
            // Inner glow
            RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blur(radius: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Interactive Glass Modifier
struct InteractiveGlassModifier: ViewModifier {
    let isEnabled: Bool
    let onInteraction: (CGSize, CGFloat) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var pressure: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .gesture(
                    DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragOffset = value.translation
                                // Simulate pressure based on velocity
                                let velocity = sqrt(pow(value.velocity.width, 2) + pow(value.velocity.height, 2))
                                pressure = min(velocity / 1000, 1.0)
                                onInteraction(dragOffset, pressure)
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                    pressure = 0
                                    onInteraction(.zero, 0)
                                }
                            }
                    )
        } else {
            content
        }
    }
}

// MARK: - UIKit Extensions for iOS 26
@available(iOS 26.0, *)
extension UIVisualEffectView {
    func addLiquidGlassFilters(style: GlassStyle) {
        // Apply CAFilters for liquid glass effect
        if let backdropLayer = layer.sublayers?.first {
            // Gaussian blur
            let blurFilter = CAFilter(name: "gaussianBlur")
            blurFilter.setValue(style.blurRadius, forKey: "inputRadius")
            
            // Saturation adjustment
            let saturationFilter = CAFilter(name: "colorSaturate")
            saturationFilter.setValue(style.saturation, forKey: "inputAmount")
            
            // Luminosity blend for glass tint
            let luminosityFilter = CAFilter(name: "luminosityBlendMode")
            
            // Variable blur for depth
            let variableBlurFilter = CAFilter(name: "variableBlur")
            variableBlurFilter.setValue(true, forKey: "inputNormalizeEdges")
            
            backdropLayer.filters = [blurFilter, saturationFilter, luminosityFilter, variableBlurFilter]
        }
    }
    
    func updateLiquidGlassEffect(refractionOffset: CGSize, lensDistortion: CGFloat) {
        if let backdropLayer = layer.sublayers?.first {
            // Update refraction transform
            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 500.0 // Perspective
            transform = CATransform3DTranslate(transform, refractionOffset.width, refractionOffset.height, 0)
            
            // Apply lens distortion
            if lensDistortion > 0 {
                let scale = 1.0 + lensDistortion
                transform = CATransform3DScale(transform, scale, scale, 1.0)
            }
            
            backdropLayer.transform = transform
        }
    }
}

// MARK: - CAFilter (Private API wrapper for iOS 26)
@available(iOS 26.0, *)
@objc class CAFilter: NSObject, NSCopying {
    @objc var name: String
    private var values: [String: Any] = [:]
    
    @objc init(name: String) {
        self.name = name
        super.init()
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        let copy = CAFilter(name: name)
        copy.values = values
        return copy
    }
    
    @objc override func setValue(_ value: Any?, forKey key: String) {
        values[key] = value
    }
    
    @objc override func value(forKey key: String) -> Any? {
        return values[key]
    }
}

// MARK: - View Extensions
@available(iOS 26.0, *)
extension View {
    func liquidGlass(style: GlassStyle = .regular, cornerRadius: CGFloat = 20, isInteractive: Bool = true) -> some View {
        modifier(LiquidGlassEffect(style: style, cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}

// MARK: - Legacy Glass Effect (iOS 25 and below)
struct LegacyGlassEffect: ViewModifier {
    let style: GlassStyle
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                LiquidVisualEffectBlur(blurStyle: blurStyleForGlass)
                    .overlay(Color.white.opacity(style.opacity * 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    private var blurStyleForGlass: UIBlurEffect.Style {
        switch style {
        case .ultraThin: return .systemUltraThinMaterial
        case .thin: return .systemThinMaterial
        case .regular: return .systemMaterial
        case .thick: return .systemThickMaterial
        case .prominent: return .systemChromeMaterial
        }
    }
}

// MARK: - Conditional View Extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Cross-Platform Glass Effect
extension View {
    func adaptiveLiquidGlass(style: GlassStyle = .regular, cornerRadius: CGFloat = 20, isInteractive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.liquidGlass(style: style, cornerRadius: cornerRadius, isInteractive: isInteractive))
        } else {
            return AnyView(self.modifier(LegacyGlassEffect(style: style, cornerRadius: cornerRadius)))
        }
    }
}

// MARK: - Visual Effect Blur
struct LiquidVisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}