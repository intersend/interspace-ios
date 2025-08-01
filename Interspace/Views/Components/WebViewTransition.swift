import SwiftUI

// MARK: - Web View Transition
/// Safari-style transition for opening web views from app icons
struct WebViewTransition: ViewModifier {
    let isPresented: Bool
    let sourceFrame: CGRect
    
    @State private var animationProgress: Double = 0
    @State private var cornerRadiusProgress: Double = 0
    @State private var shadowProgress: Double = 0
    
    // Safari-matched timing with performance optimization
    private let openDuration: Double = 0.45
    private let closeDuration: Double = 0.25
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .scaleEffect(scaleValue(for: geometry))
                .offset(offsetValue(for: geometry))
                .opacity(opacityValue)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cornerRadius(for: geometry),
                        style: .continuous
                    )
                )
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowOffset
                )
                .animation(
                    isPresented ?
                    .spring(response: openDuration * 0.9, dampingFraction: 0.82) :
                    .spring(response: closeDuration * 0.9, dampingFraction: 0.88),
                    value: animationProgress
                )
        }
        .onAppear {
            if isPresented {
                withAnimation(.easeOut(duration: 0.1)) {
                    shadowProgress = 1
                }
                animationProgress = 1
                withAnimation(.easeInOut(duration: openDuration * 0.7).delay(openDuration * 0.3)) {
                    cornerRadiusProgress = 1
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.1)) {
                    shadowProgress = 1
                }
                animationProgress = 1
                withAnimation(.easeInOut(duration: openDuration * 0.7).delay(openDuration * 0.3)) {
                    cornerRadiusProgress = 1
                }
            } else {
                withAnimation(.easeIn(duration: 0.1)) {
                    shadowProgress = 0
                }
                withAnimation(.easeInOut(duration: closeDuration * 0.5)) {
                    cornerRadiusProgress = 0
                }
                animationProgress = 0
            }
        }
    }
    
    private func scaleValue(for geometry: GeometryProxy) -> CGFloat {
        // Safari uses icon size as starting point with slight overshoot
        let iconScale = sourceFrame.width / geometry.size.width
        let progress = animationProgress
        
        if progress == 0 {
            return iconScale
        } else if progress < 0.7 {
            // Slight overshoot effect
            let overshoot = 1.02
            let t = progress / 0.7
            return iconScale + (overshoot - iconScale) * easeOutCubic(t)
        } else {
            // Settle to final size
            let t = (progress - 0.7) / 0.3
            return 1.02 - 0.02 * easeInOutCubic(t)
        }
    }
    
    private func offsetValue(for geometry: GeometryProxy) -> CGSize {
        guard animationProgress < 1 else { return .zero }
        
        // Calculate center offset with easing
        let centerX = sourceFrame.midX - geometry.size.width / 2
        let centerY = sourceFrame.midY - geometry.size.height / 2
        
        // Use cubic easing for smooth motion
        let easedProgress = easeInOutCubic(animationProgress)
        
        return CGSize(
            width: centerX * (1 - easedProgress),
            height: centerY * (1 - easedProgress)
        )
    }
    
    private var opacityValue: Double {
        // Fade in quickly at the start
        if animationProgress < 0.3 {
            return animationProgress / 0.3
        }
        return 1.0
    }
    
    private func cornerRadius(for geometry: GeometryProxy) -> CGFloat {
        // Match app icon corner radius to browser corner radius
        let iconRadius = sourceFrame.width * 0.225 // iOS app icon radius
        let browserRadius: CGFloat = 0 // Full screen browser
        
        return iconRadius + (browserRadius - iconRadius) * cornerRadiusProgress
    }
    
    private var shadowOpacity: Double {
        return 0.3 * shadowProgress
    }
    
    private var shadowRadius: CGFloat {
        return 20 * shadowProgress
    }
    
    private var shadowOffset: CGFloat {
        return 10 * shadowProgress
    }
    
    // MARK: - Easing Functions
    
    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }
    
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let t1 = 2 * t - 2
            return 1 + t1 * t1 * t1 / 2
        }
    }
}

// MARK: - Zoom Navigation Transition
@available(iOS 17.0, *)
struct ZoomNavigationTransition: Transition {
    let sourceID: AnyHashable
    let namespace: Namespace.ID
    
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase == .identity ? 1 : 0.8)
            .opacity(phase == .identity ? 1 : 0)
    }
}

// iOS 16 compatible transition using AnyTransition
extension AnyTransition {
    static func zoomNavigation(sourceID: AnyHashable, namespace: Namespace.ID) -> AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        )
    }
}

// MARK: - App Icon to Browser Transition
struct AppIconToBrowserTransition: ViewModifier {
    @Binding var isPresented: Bool
    let sourceView: AnyView
    let app: BookmarkedApp
    
    @State private var sourceFrame: CGRect = .zero
    @State private var showBrowser = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(isPresented ? 0 : 1)
            
            if isPresented {
                // Animated app icon that transitions to browser
                sourceView
                    .scaleEffect(showBrowser ? 20 : 1)
                    .opacity(showBrowser ? 0 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showBrowser)
                
                // Browser view
                if showBrowser {
                    WebBrowserView(app: app)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: 0.2)),
                            removal: .opacity.animation(.easeOut(duration: 0.2))
                        ))
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                // Start the transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showBrowser = true
                }
            } else {
                // Reverse the transition
                showBrowser = false
            }
        }
    }
}

// MARK: - Interactive Dismissal
struct InteractiveDismissModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    private let dismissThreshold: CGFloat = 150
    
    func body(content: Content) -> some View {
        content
            .offset(dragOffset)
            .scaleEffect(scaleForOffset)
            .animation(.interactiveSpring(), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        if shouldDismiss(translation: value.translation) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
    }
    
    private var scaleForOffset: CGFloat {
        let progress = min(abs(dragOffset.height) / dismissThreshold, 1.0)
        return 1.0 - (progress * 0.1) // Scale down to 0.9 at max
    }
    
    private func shouldDismiss(translation: CGSize) -> Bool {
        return translation.height > dismissThreshold ||
               abs(translation.width) > dismissThreshold
    }
}

// MARK: - View Extensions
extension View {
    func webViewTransition(isPresented: Bool, sourceFrame: CGRect) -> some View {
        modifier(WebViewTransition(isPresented: isPresented, sourceFrame: sourceFrame))
    }
    
    func appIconToBrowserTransition(isPresented: Binding<Bool>, sourceView: AnyView, app: BookmarkedApp) -> some View {
        modifier(AppIconToBrowserTransition(isPresented: isPresented, sourceView: sourceView, app: app))
    }
    
    func interactiveDismiss(isPresented: Binding<Bool>) -> some View {
        modifier(InteractiveDismissModifier(isPresented: isPresented))
    }
}