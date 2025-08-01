import SwiftUI
import UIKit

// MARK: - Liquid Safari Blur View
struct LiquidSafariBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style
    let vibrancy: Bool
    
    init(style: UIBlurEffect.Style = .systemUltraThinMaterialDark, vibrancy: Bool = false) {
        self.style = style
        self.vibrancy = vibrancy
    }
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blurEffect)
        
        if vibrancy {
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
            vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.contentView.addSubview(vibrancyView)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Liquid Safari Glass Effect
struct LiquidSafariGlass: ViewModifier {
    let cornerRadius: CGFloat
    let blurIntensity: CGFloat
    
    init(cornerRadius: CGFloat = 20, blurIntensity: CGFloat = 0.8) {
        self.cornerRadius = cornerRadius
        self.blurIntensity = blurIntensity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base blur layer
                    LiquidSafariBlur(style: .systemUltraThinMaterialDark)
                        .opacity(blurIntensity)
                    
                    // Subtle gradient overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Noise texture for depth
                    Color.white.opacity(0.02)
                        .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - Liquid Safari Spring Animation
extension Animation {
    static var liquidSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)
    }
    
    static var liquidBounce: Animation {
        .spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
    }
    
    static var liquidSmooth: Animation {
        .spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0)
    }
}

// MARK: - Elastic Scroll Modifier
struct ElasticScrollModifier: ViewModifier {
    @State private var overscrollOffset: CGFloat = 0
    @State private var isDragging = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: overscrollOffset * 0.5)
            .animation(.liquidSpring, value: overscrollOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        if value.translation.height > 0 {
                            // Elastic overscroll at top
                            overscrollOffset = pow(value.translation.height, 0.7)
                        } else {
                            overscrollOffset = 0
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.liquidBounce) {
                            overscrollOffset = 0
                        }
                    }
            )
    }
}

// MARK: - Safari Page Transition
struct SafariPageTransition: ViewModifier {
    let isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 1 : 0.93)
            .opacity(isPresented ? 1 : 0)
            .blur(radius: isPresented ? 0 : 10)
            .animation(.liquidSpring, value: isPresented)
    }
}

// MARK: - View Extensions
extension View {
    func liquidSafariGlass(cornerRadius: CGFloat = 20, blurIntensity: CGFloat = 0.8) -> some View {
        modifier(LiquidSafariGlass(cornerRadius: cornerRadius, blurIntensity: blurIntensity))
    }
    
    func elasticScroll() -> some View {
        modifier(ElasticScrollModifier())
    }
    
    func safariPageTransition(isPresented: Bool) -> some View {
        modifier(SafariPageTransition(isPresented: isPresented))
    }
}

// MARK: - Haptic Feedback Extensions
extension HapticManager {
    static func safariImpact() {
        impact(.light)
    }
    
    static func safariSelection() {
        selection()
    }
    
    static func safariNotification() {
        notification(.success)
    }
}