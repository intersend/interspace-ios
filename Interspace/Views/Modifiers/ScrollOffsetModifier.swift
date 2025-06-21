import SwiftUI

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetModifierPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Offset Modifier
struct ScrollOffsetModifier: ViewModifier {
    @Binding var offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetModifierPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetModifierPreferenceKey.self) { value in
                offset = value
            }
    }
}

// MARK: - View Extension
extension View {
    func trackScrollOffset(_ offset: Binding<CGFloat>) -> some View {
        modifier(ScrollOffsetModifier(offset: offset))
    }
}