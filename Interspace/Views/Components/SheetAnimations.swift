import SwiftUI
import Combine

// MARK: - Sheet Animation Utilities
struct SheetAnimationConstants {
    static let springResponse: Double = 0.5
    static let springDamping: Double = 0.85
    static let buttonScalePressedEffect: Double = 0.97
    static let buttonOpacityPressedEffect: Double = 0.8
    static let shimmerDuration: Double = 1.5
    static let rubberBandThreshold: CGFloat = 150
    static let rubberBandDamping: Double = 0.7
    static let transitionDuration: Double = 0.3
}

// MARK: - Custom Sheet Presentation
struct CustomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: SheetContent
    let detents: Set<PresentationDetent>
    let showDragIndicator: Bool
    let enableBackgroundInteraction: Bool
    
    init(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.large],
        showDragIndicator: Bool = true,
        enableBackgroundInteraction: Bool = true,
        @ViewBuilder content: () -> SheetContent
    ) {
        self._isPresented = isPresented
        self.sheetContent = content()
        self.detents = detents
        self.showDragIndicator = showDragIndicator
        self.enableBackgroundInteraction = enableBackgroundInteraction
    }
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if #available(iOS 16.4, *) {
                    sheetContent
                        .presentationDetents(detents)
                        .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
                        .presentationCornerRadius(30)
                        .presentationBackgroundInteraction(enableBackgroundInteraction ? .enabled : .disabled)
                        .presentationBackground(.ultraThinMaterial)
                        .presentationContentInteraction(.scrolls)
                } else {
                    sheetContent
                        .presentationDetents(detents)
                        .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
                }
            }
    }
}

// MARK: - Animated Button Style
struct AnimatedButtonStyle: ButtonStyle {
    let tint: Color
    let isProminent: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? SheetAnimationConstants.buttonScalePressedEffect : 1.0)
            .opacity(configuration.isPressed ? SheetAnimationConstants.buttonOpacityPressedEffect : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    HapticManager.impact(.light)
                }
            }
    }
}

// MARK: - Number Ticker Animation
struct NumberTickerView: View {
    let value: Double
    let format: String
    let font: Font
    let color: Color
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        Text(String(format: format, animatedValue))
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedValue)
            .onAppear {
                animatedValue = value
            }
            .onChange(of: value) { newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animatedValue = newValue
                }
            }
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200 - 100)
                .mask(content)
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Card Expand/Collapse Animation
struct ExpandableCard<Content: View>: View {
    @State private var isExpanded = false
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    HapticManager.impact(.light)
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                .padding()
            }
            
            if isExpanded {
                content
                    .padding([.horizontal, .bottom])
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                .fill(Material.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous))
    }
}

// MARK: - Rubber Band Scroll Effect
struct RubberBandScrollView<Content: View>: View {
    let content: Content
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .anchorPreference(key: ScrollOffsetPreferenceKey.self, value: .top) { [$0] }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { anchors in
                if let anchor = anchors.first {
                    let offset = geometry[anchor].y
                    scrollOffset = offset
                }
            }
            .offset(y: rubberBandOffset)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: SheetAnimationConstants.rubberBandDamping), value: scrollOffset)
        }
    }
    
    private var rubberBandOffset: CGFloat {
        if scrollOffset > 0 {
            // Overscroll at top
            return sqrt(scrollOffset) * 10
        } else {
            return 0
        }
    }
}

// MARK: - Preference Keys
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [Anchor<CGPoint>] = []
    
    static func reduce(value: inout [Anchor<CGPoint>], nextValue: () -> [Anchor<CGPoint>]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Focus Transition Effect
struct FocusTransitionModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let onFocusChange: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
            .onChange(of: isFocused) { newValue in
                if newValue {
                    HapticManager.impact(.light)
                }
                onFocusChange(newValue)
            }
    }
}

// MARK: - QR Code Fade Animation
struct QRCodeFadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    opacity = 1
                    scale = 1
                }
            }
    }
}

// MARK: - Success Animation View
struct SuccessAnimationView: View {
    @State private var showCheckmark = false
    @State private var showCircle = false
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(DesignTokens.Colors.success, lineWidth: 3)
                .frame(width: 80, height: 80)
                .scaleEffect(showCircle ? 1 : 0)
                .opacity(showCircle ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCircle)
            
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.success)
                .scaleEffect(showCheckmark ? 1 : 0)
                .opacity(showCheckmark ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showCheckmark)
        }
        .onAppear {
            showCircle = true
            showCheckmark = true
            HapticManager.notification(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func customSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.large],
        showDragIndicator: Bool = true,
        enableBackgroundInteraction: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(CustomSheetModifier(
            isPresented: isPresented,
            detents: detents,
            showDragIndicator: showDragIndicator,
            enableBackgroundInteraction: enableBackgroundInteraction,
            content: content
        ))
    }
    
    func shimmer(duration: Double = SheetAnimationConstants.shimmerDuration) -> some View {
        self.modifier(ShimmerModifier(duration: duration))
    }
    
    func focusTransition(onFocusChange: @escaping (Bool) -> Void) -> some View {
        self.modifier(FocusTransitionModifier(onFocusChange: onFocusChange))
    }
    
    func qrCodeFadeIn() -> some View {
        self.modifier(QRCodeFadeInModifier())
    }
    
    func animatedButton(tint: Color = DesignTokens.Colors.primary, isProminent: Bool = false) -> some View {
        self.buttonStyle(AnimatedButtonStyle(tint: tint, isProminent: isProminent))
    }
}

// MARK: - Animated List Appearance
struct AnimatedListModifier: ViewModifier {
    let index: Int
    @State private var appeared = false
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
                value: appeared
            )
            .onAppear {
                appeared = true
            }
    }
}

extension View {
    func animatedListItem(index: Int) -> some View {
        self.modifier(AnimatedListModifier(index: index))
    }
}