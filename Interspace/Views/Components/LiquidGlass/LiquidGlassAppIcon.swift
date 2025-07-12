import SwiftUI

// MARK: - Liquid Glass App Icon (iOS 26 Specification)

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
    @State private var glassShimmer: Double = 0
    
    // iOS 26 precise specifications
    private var cornerRadius: CGFloat {
        iconSize * 0.225 // Exactly 22.5% - iOS standard
    }
    
    private var shadowRadius: CGFloat {
        isDragging ? 12 : 5 // Enhanced shadow when dragging
    }
    
    private var shadowY: CGFloat {
        isDragging ? 8 : 3 // Deeper shadow when lifted
    }
    
    var body: some View {
        VStack(spacing: 5) { // iOS standard spacing between icon and label
            // Icon container with all effects
            ZStack {
                // Main icon view
                iconView
                    .frame(width: iconSize, height: iconSize)
                    .scaleEffect(isPressed ? 0.92 : 1.0) // More pronounced press
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
                
                // Delete button overlay
                if isEditMode {
                    deleteButton
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.1).combined(with: .opacity),
                            removal: .scale(scale: 0.1).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: iconSize, height: iconSize)
            .onTapGesture {
                if !isEditMode {
                    // Precise haptic timing
                    HapticManager.impact(.light)
                    
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isPressed = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                            isPressed = false
                        }
                        onTap()
                    }
                }
            }
            
            // App name label
            Text(app.name)
                .font(.system(size: 11.5, weight: .regular, design: .default))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 16, height: 28, alignment: .top)
                .minimumScaleFactor(0.85)
                .lineSpacing(1)
        }
        .opacity(isDragging ? 0.85 : 1.0)
        .scaleEffect(isDropTarget ? 0.82 : 1.0) // More dramatic scale for drop target
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isDropTarget)
        .onAppear {
            // Subtle shimmer animation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                glassShimmer = 1
            }
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            // Base shadow layer for depth
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.3))
                .blur(radius: shadowRadius)
                .offset(y: shadowY)
                .scaleEffect(0.95)
            
            // Multi-layered glass construction
            if let iconUrl = app.iconUrl, !iconUrl.isEmpty {
                // App icon with enhanced glass layers
                AsyncImage(url: URL(string: iconUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        ZStack {
                            // Base icon
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: iconSize, height: iconSize)
                                .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
                            
                            // Glass overlay layers
                            glassOverlay
                            
                            // Edge highlight
                            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.5),
                                            .white.opacity(0.1),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(
                            color: .black.opacity(0.15),
                            radius: 2,
                            x: 0,
                            y: 1
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
            // Base shadow for depth
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.3))
                .blur(radius: shadowRadius)
                .offset(y: shadowY)
                .scaleEffect(0.95)
            
            // Gradient background with refined colors
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: gradientColors(for: app.name)[0], location: 0),
                            .init(color: gradientColors(for: app.name)[1], location: 0.5),
                            .init(color: gradientColors(for: app.name)[1].opacity(0.8), location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Glass overlay layers
            glassOverlay
            
            // Edge highlight
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.5),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            
            // App initial with refined typography
            Text(app.name.prefix(1).uppercased())
                .font(.system(size: iconSize * 0.38, weight: .medium, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
    }
    
    @ViewBuilder
    private var glassOverlay: some View {
        // iOS 26 multi-layer liquid glass effect
        ZStack {
            // Layer 1: Base glass gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white.opacity(0.18), location: 0),
                    .init(color: .white.opacity(0.12), location: 0.3),
                    .init(color: .white.opacity(0.05), location: 0.7),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Layer 2: Top specular highlight
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.35), location: 0),
                        .init(color: .white.opacity(0.15), location: 0.4),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: iconSize * 0.35)
                .blur(radius: 1.5)
                
                Spacer()
            }
            
            // Layer 3: Shimmer effect
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .white.opacity(0.1), location: 0.5),
                    .init(color: .clear, location: 0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(45))
            .offset(x: glassShimmer * iconSize * 2 - iconSize)
            .opacity(0.6)
            
            // Layer 4: Bottom refraction
            VStack {
                Spacer()
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .black.opacity(0.05),
                        .black.opacity(0.08)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: iconSize * 0.2)
                .blur(radius: 0.5)
            }
        }
        .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        VStack {
            HStack {
                Button(action: {
                    // Immediate haptic
                    HapticManager.impact(.rigid)
                    
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        deleteButtonScale = 0.75
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            deleteButtonScale = 1.0
                        }
                        onDelete()
                    }
                }) {
                    ZStack {
                        // Outer shadow for depth
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 26, height: 26)
                            .blur(radius: 2)
                            .offset(y: 1)
                        
                        // Red background circle with exact iOS color
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.231, blue: 0.188),
                                        Color(red: 0.95, green: 0.20, blue: 0.16)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 24, height: 24)
                        
                        // Inner shadow for depth
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 24, height: 24)
                        
                        // White X with precise weight
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(deleteButtonScale)
                
                Spacer()
            }
            Spacer()
        }
        .offset(x: -8, y: -8) // Precise iOS positioning
    }
    
    // MARK: - Helper Methods
    
    private func gradientColors(for name: String) -> [Color] {
        // iOS 26 sophisticated color palette generation
        let hash = abs(name.hashValue)
        let colorIndex = hash % 12
        
        // Carefully curated color pairs matching iOS 26 aesthetics
        let colorPairs: [[Color]] = [
            [Color(red: 0.39, green: 0.58, blue: 1.0), Color(red: 0.25, green: 0.45, blue: 0.95)], // Blue
            [Color(red: 1.0, green: 0.38, blue: 0.29), Color(red: 0.95, green: 0.25, blue: 0.18)], // Red
            [Color(red: 0.35, green: 0.84, blue: 0.39), Color(red: 0.25, green: 0.75, blue: 0.30)], // Green
            [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 0.95, green: 0.48, blue: 0.0)], // Orange
            [Color(red: 0.69, green: 0.32, blue: 0.87), Color(red: 0.59, green: 0.22, blue: 0.77)], // Purple
            [Color(red: 1.0, green: 0.21, blue: 0.55), Color(red: 0.90, green: 0.11, blue: 0.45)], // Pink
            [Color(red: 0.0, green: 0.78, blue: 0.75), Color(red: 0.0, green: 0.68, blue: 0.65)], // Teal
            [Color(red: 1.0, green: 0.80, blue: 0.0), Color(red: 0.95, green: 0.70, blue: 0.0)], // Yellow
            [Color(red: 0.51, green: 0.43, blue: 0.50), Color(red: 0.41, green: 0.33, blue: 0.40)], // Gray
            [Color(red: 0.20, green: 0.67, blue: 0.33), Color(red: 0.10, green: 0.57, blue: 0.23)], // Forest
            [Color(red: 0.95, green: 0.26, blue: 0.21), Color(red: 0.85, green: 0.16, blue: 0.11)], // Crimson
            [Color(red: 0.40, green: 0.20, blue: 0.60), Color(red: 0.30, green: 0.10, blue: 0.50)]  // Indigo
        ]
        
        return colorPairs[colorIndex]
    }
}
