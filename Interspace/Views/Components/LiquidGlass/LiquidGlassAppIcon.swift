import SwiftUI

// MARK: - Liquid Glass App Icon

struct LiquidGlassAppIcon: View {
    let app: BookmarkedApp
    let iconSize: CGFloat
    @Binding var isEditMode: Bool
    let isDragging: Bool
    let isDropTarget: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    // Animation states
    @State private var isPressed = false
    @State private var deleteButtonScale: CGFloat = 1.0
    
    // iOS specifications
    private var cornerRadius: CGFloat {
        iconSize * 0.225 // 22.5% of icon size
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            iconView
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .overlay(
                    deleteButton
                        .opacity(isEditMode ? 1 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditMode)
                )
                .onTapGesture {
                    if !isEditMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                        HapticManager.selection()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                isPressed = false
                            }
                            onTap()
                        }
                    }
                }
            
            // App name
            Text(app.name)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 12, height: 28, alignment: .top)
                .minimumScaleFactor(0.8)
        }
        .opacity(isDragging ? 0.8 : 1.0)
        .scaleEffect(isDropTarget ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDropTarget)
    }
    
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            // Multi-layered glass construction
            if let iconUrl = app.iconUrl, !iconUrl.isEmpty {
                // App icon with glass overlay
                AsyncImage(url: URL(string: iconUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: iconSize, height: iconSize)
                            .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
                            .overlay(glassOverlay)
                            .glassLayer(cornerRadius: cornerRadius)
                            .shadow(
                                color: .black.opacity(0.2),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    case .failure(_), .empty:
                        placeholderIcon
                    @unknown default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
    }
    
    @ViewBuilder
    private var placeholderIcon: some View {
        ZStack {
            // Gradient background
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors(for: app.name)),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(glassOverlay)
                .glassLayer(cornerRadius: cornerRadius)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            
            // App initial
            Text(app.name.prefix(1).uppercased())
                .font(.system(size: iconSize * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private var glassOverlay: some View {
        // Multi-layer glass effect
        ZStack {
            // Base glass layer with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.05),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Specular highlight
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.2),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: iconSize * 0.3)
                .blur(radius: 2)
                
                Spacer()
            }
        }
        .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        VStack {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        deleteButtonScale = 0.8
                    }
                    
                    HapticManager.impact(.medium)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            deleteButtonScale = 1.0
                        }
                        onDelete()
                    }
                }) {
                    ZStack {
                        // Red background circle
                        Circle()
                            .fill(Color(red: 1, green: 0.231, blue: 0.188)) // iOS red
                            .frame(width: 24, height: 24)
                        
                        // White X (not minus)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(deleteButtonScale)
                
                Spacer()
            }
            Spacer()
        }
        .offset(x: -6, y: -6)
    }
    
    // MARK: - Helper Methods
    
    private func gradientColors(for name: String) -> [Color] {
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.1).truncatingRemainder(dividingBy: 1.0)
        
        return [
            Color(hue: hue1, saturation: 0.7, brightness: 0.8),
            Color(hue: hue2, saturation: 0.7, brightness: 0.7)
        ]
    }
}