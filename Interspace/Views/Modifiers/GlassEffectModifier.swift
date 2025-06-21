import SwiftUI

// MARK: - AnyShape Wrapper
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Glass Effect Style
public struct GlassEffectStyle {
    let material: Material
    let tintColor: Color?
    let isInteractive: Bool
    
    private init(material: Material, tintColor: Color? = nil, isInteractive: Bool = false) {
        self.material = material
        self.tintColor = tintColor
        self.isInteractive = isInteractive
    }
    
    // MARK: - Predefined Styles
    public static let ultraThin = GlassEffectStyle(material: .ultraThinMaterial)
    public static let thin = GlassEffectStyle(material: .thinMaterial)
    public static let regular = GlassEffectStyle(material: .regularMaterial)
    public static let thick = GlassEffectStyle(material: .thickMaterial)
    public static let ultraThick = GlassEffectStyle(material: .ultraThickMaterial)
    
    // MARK: - Modifiers
    public func tint(_ color: Color) -> GlassEffectStyle {
        GlassEffectStyle(material: material, tintColor: color, isInteractive: isInteractive)
    }
    
    public func interactive() -> GlassEffectStyle {
        GlassEffectStyle(material: material, tintColor: tintColor, isInteractive: true)
    }
}

// MARK: - Glass Shape
public enum GlassShape {
    case rect(cornerRadius: CGFloat = 16)
    case capsule
    case circle
    
    func shape() -> AnyShape {
        switch self {
        case .rect(let cornerRadius):
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .capsule:
            return AnyShape(Capsule())
        case .circle:
            return AnyShape(Circle())
        }
    }
}

// MARK: - Glass Effect View Modifier
struct GlassEffectModifier: ViewModifier {
    let style: GlassEffectStyle
    let shape: GlassShape
    let isEnabled: Bool
    
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    // Base material layer
                    shape.shape()
                        .fill(style.material)
                    
                    // Tint layer if specified
                    if let tintColor = style.tintColor {
                        shape.shape()
                            .fill(tintColor.opacity(0.15))
                    }
                }
                .drawingGroup() // Optimize rendering
            )
            .overlay(
                // Glass border
                shape.shape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                    .drawingGroup() // Optimize rendering
            )
            .clipShape(shape.shape())
            .scaleEffect(isPressed && style.isInteractive ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed) // Faster animation
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    if style.isInteractive {
                        isPressed = pressing
                    }
                },
                perform: {}
            )
            .opacity(isEnabled ? 1 : 0.6)
    }
}

// MARK: - Glass Effect ID Modifier
struct GlassEffectIDModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a glass effect to the view
    /// - Parameters:
    ///   - style: The glass effect style to apply
    ///   - shape: The shape of the glass effect
    ///   - isEnabled: Whether the glass effect is enabled
    public func glassEffect(
        _ style: GlassEffectStyle = .regular,
        in shape: GlassShape = .rect(),
        isEnabled: Bool = true
    ) -> some View {
        modifier(GlassEffectModifier(style: style, shape: shape, isEnabled: isEnabled))
    }
    
    /// Adds an ID for glass effect transitions
    /// - Parameters:
    ///   - id: The unique identifier for this glass element
    ///   - namespace: The namespace for the transition
    public func glassEffectID<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        modifier(GlassEffectIDModifier(id: id, namespace: namespace))
    }
}

// MARK: - Glass Effect Container
public struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    public init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        content
            .environment(\.glassContainerSpacing, spacing)
    }
}

// MARK: - Glass Effect Union
struct GlassEffectUnionModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: "glass_union_\(id)", in: namespace, isSource: false)
    }
}

extension View {
    /// Groups multiple glass effects into a single unified shape
    public func glassEffectUnion<ID: Hashable>(id: ID, namespace: Namespace.ID) -> some View {
        modifier(GlassEffectUnionModifier(id: id, namespace: namespace))
    }
}

// MARK: - Environment Keys
private struct GlassContainerSpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 20
}

extension EnvironmentValues {
    var glassContainerSpacing: CGFloat {
        get { self[GlassContainerSpacingKey.self] }
        set { self[GlassContainerSpacingKey.self] = newValue }
    }
}

// MARK: - Liquid Glass Card Modifier
struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let material: Material
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(0.2),
                radius: 10,
                x: 0,
                y: 5
            )
    }
}

// MARK: - Inset Grouped List Style Modifier
struct InsetGroupedListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.systemGroupedBackground)
            .listStyle(.plain)
    }
}

// MARK: - Glass Morphing Transition
struct GlassMorphingTransition: ViewModifier {
    let isVisible: Bool
    let id: String
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if isVisible {
            content
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    )
                )
                .matchedGeometryEffect(id: "morph_\(id)", in: namespace)
        }
    }
}

extension View {
    /// Applies a liquid glass card style
    func liquidGlassCard(
        cornerRadius: CGFloat = DesignTokens.CornerRadius.card,
        material: Material = .regularMaterial
    ) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, material: material))
    }
    
    /// Applies inset grouped list styling
    func insetGroupedListStyle() -> some View {
        modifier(InsetGroupedListModifier())
    }
    
    /// Applies glass morphing transition
    func glassMorphingTransition(isVisible: Bool, id: String, namespace: Namespace.ID) -> some View {
        modifier(GlassMorphingTransition(isVisible: isVisible, id: id, namespace: namespace))
    }
}