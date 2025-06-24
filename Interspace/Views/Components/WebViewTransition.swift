import SwiftUI

// MARK: - Web View Transition
struct WebViewTransition: ViewModifier {
    let isPresented: Bool
    let sourceFrame: CGRect
    
    @State private var animationProgress: Double = 0
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .scaleEffect(scaleValue(for: geometry))
                .offset(offsetValue(for: geometry))
                .opacity(opacityValue)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animationProgress)
        }
        .onAppear {
            if isPresented {
                animationProgress = 1
            }
        }
        .onChange(of: isPresented) { newValue in
            animationProgress = newValue ? 1 : 0
        }
    }
    
    private func scaleValue(for geometry: GeometryProxy) -> CGFloat {
        let startScale = min(sourceFrame.width / geometry.size.width, 
                             sourceFrame.height / geometry.size.height)
        return animationProgress == 0 ? startScale : 1.0
    }
    
    private func offsetValue(for geometry: GeometryProxy) -> CGSize {
        guard animationProgress < 1 else { return .zero }
        
        let centerX = sourceFrame.midX - geometry.size.width / 2
        let centerY = sourceFrame.midY - geometry.size.height / 2
        
        return CGSize(
            width: centerX * (1 - animationProgress),
            height: centerY * (1 - animationProgress)
        )
    }
    
    private var opacityValue: Double {
        return animationProgress
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