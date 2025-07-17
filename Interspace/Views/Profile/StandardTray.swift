import SwiftUI

/// A tray view that mimics Apple’s modern sheet/tray design.
///
/// Example usage:
/// ```swift
/// StandardTray(title: "Example Title", titleDisplayMode: .large, onDismiss: { print("Dismissed") }) {
///     Text("Content goes here")
/// }
/// ```
public struct StandardTray<Content: View>: View {
    
    public enum TrayTitleDisplayMode {
        case inline
        case large
        case hidden
    }
    
    let title: String
    let titleDisplayMode: TrayTitleDisplayMode
    let onDismiss: () -> Void
    let content: () -> Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(title: String,
                titleDisplayMode: TrayTitleDisplayMode = .inline,
                onDismiss: @escaping () -> Void,
                @ViewBuilder content: @escaping () -> Content)
    {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.onDismiss = onDismiss
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, titleDisplayMode == .large ? 8 : 10)
            
            Divider()
                .background(Color.primary.opacity(colorScheme == .dark ? 0.3 : 0.15))
            
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, safeAreaBottomInset + 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 28))
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private var header: some View {
        HStack(alignment: .center) {
            titleView
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20, weight: .semibold))
                    .padding(10)
                    .contentShape(Rectangle())
                    .accessibilityLabel(Text("Close"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("StandardTrayCloseButton")
        }
    }
    
    @ViewBuilder
    private var titleView: some View {
        switch titleDisplayMode {
        case .large:
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .inline:
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .hidden:
            EmptyView()
        }
    }
    
    private var safeAreaBottomInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - RoundedCornersShape

private struct RoundedCornersShape: Shape {
    let corners: UIRectCorner
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview("Large Title") {
    StandardTray(title: "Tray Title", titleDisplayMode: .large, onDismiss: {}) {
        VStack(spacing: 12) {
            ForEach(0..<20) { i in
                Text("Item \(i + 1)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }
    .frame(height: 400)
    .background(Color(UIColor.systemBackground))
}

#Preview("Inline Title") {
    StandardTray(title: "Tray Title", titleDisplayMode: .inline, onDismiss: {}) {
        VStack(spacing: 12) {
            ForEach(0..<20) { i in
                Text("Item \(i + 1)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }
    .frame(height: 400)
    .background(Color(UIColor.systemBackground))
}

#Preview("Hidden Title") {
    StandardTray(title: "Tray Title", titleDisplayMode: .hidden, onDismiss: {}) {
        VStack(spacing: 12) {
            ForEach(0..<20) { i in
                Text("Item \(i + 1)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }
    .frame(height: 400)
    .background(Color(UIColor.systemBackground))
}
