import SwiftUI

struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    
    @State private var dragOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    private let maxHeight: CGFloat
    private let cornerRadius: CGFloat = DesignTokens.CornerRadius.xl
    private let handleHeight: CGFloat = 5
    private let handleWidth: CGFloat = 36
    private let dragThreshold: CGFloat = 100
    
    init(
        isPresented: Binding<Bool>,
        maxHeight: CGFloat = UIScreen.main.bounds.height * 0.6,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.maxHeight = maxHeight
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Background overlay
                Color.black
                    .opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                
                // Bottom sheet
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: handleWidth, height: handleHeight)
                            .padding(.top, DesignTokens.Spacing.md)
                        
                        // Content
                        content
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.bottom, DesignTokens.Spacing.lg)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ViewHeightKey.self, value: geometry.size.height)
                                }
                            )
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius)
                    )
                    .offset(y: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                withAnimation(.spring()) {
                                    if value.translation.height > dragThreshold {
                                        dismiss()
                                    } else {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onPreferenceChange(ViewHeightKey.self) { height in
            contentHeight = height
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
    
    private func dismiss() {
        withAnimation(.spring()) {
            isPresented = false
            dragOffset = 0
        }
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}