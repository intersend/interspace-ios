import SwiftUI

// MARK: - Liquid Glass Material

struct LiquidGlassMaterial: ViewModifier {
    let intensity: MaterialIntensity
    let tintColor: Color?
    let shadowRadius: CGFloat
    
    enum MaterialIntensity {
        case ultraThin
        case thin
        case regular
        case thick
        
        var material: Material {
            switch self {
            case .ultraThin: return .ultraThinMaterial
            case .thin: return .thinMaterial
            case .regular: return .regularMaterial
            case .thick: return .thickMaterial
            }
        }
        
        var overlayOpacity: Double {
            switch self {
            case .ultraThin: return 0.05
            case .thin: return 0.1
            case .regular: return 0.15
            case .thick: return 0.2
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(intensity.material)
            .overlay(
                // Gradient overlay for depth
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(intensity.overlayOpacity),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Optional tint color
                tintColor?.opacity(0.1)
            )
            .shadow(
                color: .black.opacity(0.2),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius / 2
            )
    }
}

// MARK: - Glass Layer Effects

struct GlassLayerEffect: ViewModifier {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Specular highlight on top edge
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .center
                    )
                    .frame(height: 2)
                    .blur(radius: 1)
                    
                    Spacer()
                }
                .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
            )
            .overlay(
                // Subtle border for definition
                ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.1), lineWidth: borderWidth)
            )
    }
}

// MARK: - Dynamic Background Adaptation

struct DynamicBackgroundAdapter: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let baseColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass layer
                    Color.clear
                        .background(.ultraThinMaterial)
                    
                    // Dynamic color overlay
                    baseColor
                        .opacity(colorScheme == .dark ? 0.2 : 0.1)
                        .blendMode(.plusLighter)
                }
            )
    }
}

// MARK: - View Extensions

extension View {
    func liquidGlass(
        intensity: LiquidGlassMaterial.MaterialIntensity = .thin,
        tintColor: Color? = nil,
        shadowRadius: CGFloat = 4
    ) -> some View {
        modifier(LiquidGlassMaterial(
            intensity: intensity,
            tintColor: tintColor,
            shadowRadius: shadowRadius
        ))
    }
    
    func glassLayer(cornerRadius: CGFloat, borderWidth: CGFloat = 0.5) -> some View {
        modifier(GlassLayerEffect(
            cornerRadius: cornerRadius,
            borderWidth: borderWidth
        ))
    }
    
    func dynamicBackground(baseColor: Color) -> some View {
        modifier(DynamicBackgroundAdapter(baseColor: baseColor))
    }
}