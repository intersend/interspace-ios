import SwiftUI

// MARK: - Fluid Web Transition
struct FluidWebTransition: ViewModifier {
    let isPresented: Bool
    let sourceFrame: CGRect
    let app: BookmarkedApp
    
    @State private var phase: TransitionPhase = .initial
    @State private var glassExpansion: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var glassDistortion: CGFloat = 0
    
    enum TransitionPhase {
        case initial
        case expanding
        case morphing
        case final
    }
    
    func body(content: Content) -> some View {
        ZStack {
            // Background scrim
            if phase != .initial {
                Color.black
                    .opacity(contentOpacity * 0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // Glass morph effect
            if phase == .expanding || phase == .morphing {
                GlassMorphView(
                    sourceFrame: sourceFrame,
                    expansion: glassExpansion,
                    distortion: glassDistortion,
                    iconURL: app.iconUrl
                )
                .allowsHitTesting(false)
            }
            
            // Main content
            content
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
                .offset(contentOffset)
                .blur(radius: phase == .morphing ? 2 : 0)
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                animateIn()
            } else {
                animateOut()
            }
        }
    }
    
    private var contentScale: CGFloat {
        switch phase {
        case .initial: return 0.001
        case .expanding: return 0.8
        case .morphing: return 0.95
        case .final: return 1.0
        }
    }
    
    private var contentOffset: CGSize {
        switch phase {
        case .initial:
            let centerX = sourceFrame.midX - UIScreen.main.bounds.midX
            let centerY = sourceFrame.midY - UIScreen.main.bounds.midY
            return CGSize(width: centerX, height: centerY)
        case .expanding:
            return CGSize(width: 0, height: 50)
        case .morphing, .final:
            return .zero
        }
    }
    
    private func animateIn() {
        // Phase 1: Initial setup
        phase = .initial
        
        // Phase 2: Glass expansion
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            phase = .expanding
            glassExpansion = 1.0
        }
        
        // Phase 3: Morphing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                phase = .morphing
                glassDistortion = 1.0
                contentOpacity = 0.8
            }
        }
        
        // Phase 4: Final state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                phase = .final
                glassDistortion = 0
                contentOpacity = 1.0
            }
        }
    }
    
    private func animateOut() {
        // Reverse animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            phase = .morphing
            contentOpacity = 0.5
            glassDistortion = 0.5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                phase = .expanding
                glassExpansion = 0.5
                contentOpacity = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .initial
            glassExpansion = 0
            glassDistortion = 0
        }
    }
}

// MARK: - Glass Morph View
struct GlassMorphView: View {
    let sourceFrame: CGRect
    let expansion: CGFloat
    let distortion: CGFloat
    let iconURL: String?
    
    @State private var ripples: [RippleEffect] = []
    
    var body: some View {
        Canvas { context, size in
            // Draw morphing glass effect
            let expandedRadius = sourceFrame.width * (1 + expansion * 20)
            let center = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
            
            // Glass layers
            for i in 0..<5 {
                let layerExpansion = expansion * CGFloat(5 - i) / 5
                let layerRadius = sourceFrame.width/2 + (expandedRadius - sourceFrame.width/2) * layerExpansion
                let layerOpacity = (1 - layerExpansion) * 0.3
                
                // Morphing shape
                let path = morphingPath(
                    center: center,
                    radius: layerRadius,
                    distortion: distortion * CGFloat(i) / 5
                )
                
                context.fill(
                    path,
                    with: .color(.white.opacity(layerOpacity))
                )
                
                // Glass edge
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            .white.opacity(0.6),
                            .white.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            }
            
            // Ripple effects
            for ripple in ripples {
                drawRipple(ripple, in: context, center: center)
            }
        }
        .onAppear {
            createRipples()
        }
    }
    
    private func morphingPath(center: CGPoint, radius: CGFloat, distortion: CGFloat) -> Path {
        Path { path in
            if distortion < 0.1 {
                // Circle
                path.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            } else {
                // Morphing rounded rectangle
                let screenBounds = UIScreen.main.bounds
                let morphProgress = min(distortion, 1.0)
                
                let rect = CGRect(
                    x: mix(center.x - radius, 0, morphProgress),
                    y: mix(center.y - radius, 0, morphProgress),
                    width: mix(radius * 2, screenBounds.width, morphProgress),
                    height: mix(radius * 2, screenBounds.height, morphProgress)
                )
                
                let cornerRadius = mix(radius, 40, 1 - morphProgress)
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
            }
        }
    }
    
    private func createRipples() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                let ripple = RippleEffect(
                    id: UUID(),
                    startTime: Date(),
                    duration: 1.5,
                    maxRadius: 200
                )
                ripples.append(ripple)
                
                // Remove after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + ripple.duration) {
                    ripples.removeAll { $0.id == ripple.id }
                }
            }
        }
    }
    
    private func drawRipple(_ ripple: RippleEffect, in context: GraphicsContext, center: CGPoint) {
        let elapsed = Date().timeIntervalSince(ripple.startTime)
        let progress = min(elapsed / ripple.duration, 1.0)
        let radius = ripple.maxRadius * progress
        let opacity = (1 - progress) * 0.3
        
        let path = Path { path in
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        
        context.stroke(
            path,
            with: .color(.white.opacity(opacity)),
            lineWidth: 2
        )
    }
    
    private func mix<T: BinaryFloatingPoint>(_ a: T, _ b: T, _ t: T) -> T {
        return a + (b - a) * t
    }
}

// MARK: - Ripple Effect
struct RippleEffect: Identifiable {
    let id: UUID
    let startTime: Date
    let duration: TimeInterval
    let maxRadius: CGFloat
}

// MARK: - Enhanced App Icon Transition
struct EnhancedAppIconTransition: ViewModifier {
    @Binding var isPresented: Bool
    let app: BookmarkedApp
    
    @State private var iconScale: CGFloat = 1.0
    @State private var iconBlur: CGFloat = 0
    @State private var glassOpacity: Double = 0
    @State private var browserOpacity: Double = 0
    @State private var iconRotation: Angle = .zero
    
    func body(content: Content) -> some View {
        ZStack {
            if !isPresented {
                content
            } else {
                // Animated app icon
                AsyncImage(url: URL(string: app.iconUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "app.fill")
                        .font(.system(size: 40))
                        .foregroundColor(DesignTokens.Colors.primary)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(iconScale)
                .rotationEffect(iconRotation)
                .blur(radius: iconBlur)
                .overlay(
                    RoundedRectangle(cornerRadius: 14 * iconScale, style: .continuous)
                        .fill(Color.white.opacity(glassOpacity * 0.2))
                        .blur(radius: iconBlur)
                )
                
                // Browser view with transition
                if browserOpacity > 0 {
                    WebBrowserView(app: app)
                        .opacity(browserOpacity)
                        .scaleEffect(0.95 + (browserOpacity * 0.05))
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                animateToWebView()
            } else {
                animateToIcon()
            }
        }
    }
    
    private func animateToWebView() {
        // Stage 1: Icon preparation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            iconScale = 1.2
            glassOpacity = 0.5
        }
        
        // Stage 2: Icon expansion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                iconScale = 10
                iconBlur = 20
                iconRotation = .degrees(90)
                glassOpacity = 1
            }
        }
        
        // Stage 3: Browser fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.2)) {
                browserOpacity = 1
            }
        }
    }
    
    private func animateToIcon() {
        // Reverse animation
        withAnimation(.easeOut(duration: 0.2)) {
            browserOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                iconScale = 1.0
                iconBlur = 0
                iconRotation = .zero
                glassOpacity = 0
            }
        }
    }
}

// MARK: - Pull to Dismiss Modifier
struct PullToDismissModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var dragVelocity: CGFloat = 0
    @State private var rubberBandScale: CGFloat = 1.0
    @State private var glassDistortion: CGFloat = 0
    
    private let dismissThreshold: CGFloat = 200
    private let velocityThreshold: CGFloat = 1000
    
    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset.height)
            .scaleEffect(rubberBandScale)
            .overlay(
                // Glass distortion overlay
                Color.clear
                    .adaptiveLiquidGlass(
                        style: GlassStyle.ultraThin,
                        cornerRadius: 40,
                        isInteractive: false
                    )
                    .opacity(glassDistortion)
                    .allowsHitTesting(false)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .animation(.interactiveSpring(), value: dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: rubberBandScale)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        // Only allow downward drag
        if value.translation.height > 0 {
            // Rubber band effect
            let resistance: CGFloat = 0.5
            let resistedHeight = value.translation.height * resistance
            
            dragOffset = CGSize(width: 0, height: resistedHeight)
            
            // Calculate velocity
            dragVelocity = value.velocity.height
            
            // Scale and distortion based on drag
            let progress = min(resistedHeight / dismissThreshold, 1.0)
            rubberBandScale = 1.0 - (progress * 0.05)
            glassDistortion = progress * 0.3
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let shouldDismiss = value.translation.height > dismissThreshold ||
                           dragVelocity > velocityThreshold
        
        if shouldDismiss {
            // Dismiss with fluid animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                dragOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
                rubberBandScale = 0.9
                glassDistortion = 0.5
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        } else {
            // Spring back
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                dragOffset = .zero
                rubberBandScale = 1.0
                glassDistortion = 0
            }
        }
        
        dragVelocity = 0
    }
}

// MARK: - View Extensions
extension View {
    func fluidWebTransition(isPresented: Bool, sourceFrame: CGRect, app: BookmarkedApp) -> some View {
        modifier(FluidWebTransition(isPresented: isPresented, sourceFrame: sourceFrame, app: app))
    }
    
    func enhancedAppIconTransition(isPresented: Binding<Bool>, app: BookmarkedApp) -> some View {
        modifier(EnhancedAppIconTransition(isPresented: isPresented, app: app))
    }
    
    func pullToDismiss(isPresented: Binding<Bool>) -> some View {
        modifier(PullToDismissModifier(isPresented: isPresented))
    }
}