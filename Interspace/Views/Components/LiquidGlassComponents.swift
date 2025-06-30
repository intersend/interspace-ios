import SwiftUI

// MARK: - Liquid Glass Design System for iOS 26

// MARK: - Glass Material
struct LiquidGlassMaterial: ViewModifier {
    let intensity: Double
    let tint: Color
    
    init(intensity: Double = 0.8, tint: Color = .clear) {
        self.intensity = intensity
        self.tint = tint
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(intensity)
                    
                    // Tint layer
                    if tint != .clear {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(tint.opacity(0.1))
                    }
                    
                    // Specular highlight
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                    .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .blendMode(.plusLighter)
                    
                    // Edge glow
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Liquid Button Style
struct LiquidGlassButtonStyle: ButtonStyle {
    let isProminent: Bool
    let tint: Color
    
    init(isProminent: Bool = false, tint: Color = .blue) {
        self.isProminent = isProminent
        self.tint = tint
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .foregroundColor(isProminent ? .white : tint)
            .background {
                if isProminent {
                    // Filled button
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint)
                        
                        // Glass overlay
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.plusLighter)
                    }
                } else {
                    // Glass button
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass Card
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 20
    
    init(padding: CGFloat = 20, cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .modifier(LiquidGlassMaterial())
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - OAuth Provider Button
struct OAuthProviderButton: View {
    let provider: OAuthProviderInfo
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Provider icon
                OAuthProviderIcon(provider: provider.id, size: 24)
                    .foregroundColor(provider.tintColor)
                
                Text("Continue with \(provider.displayName)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .opacity(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .background {
            ZStack {
                // Base glass
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Provider tint
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(provider.tintColor.opacity(isHovered ? 0.15 : 0.08))
                
                // Border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                provider.tintColor.opacity(0.3),
                                provider.tintColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Highlight
                if isHovered {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.plusLighter)
                }
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .shadow(color: provider.tintColor.opacity(isHovered ? 0.3 : 0.1), radius: isHovered ? 15 : 8, y: isHovered ? 8 : 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}


// MARK: - Liquid Glass Sheet
struct LiquidGlassSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Background blur
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                
                // Sheet content
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        content
                            .padding(.bottom, 34) // Safe area
                    }
                    .modifier(LiquidGlassMaterial(intensity: 0.95))
                    .clipShape(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .offset(y: 30)
                    )
                    .offset(y: 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPresented)
    }
}

// MARK: - Extensions
extension View {
    func liquidGlass(intensity: Double = 0.8, tint: Color = .clear) -> some View {
        self.modifier(LiquidGlassMaterial(intensity: intensity, tint: tint))
    }
}