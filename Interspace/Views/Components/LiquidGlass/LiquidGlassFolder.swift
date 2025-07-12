import SwiftUI

// MARK: - Liquid Glass Folder Icon (iOS 26 2x2 Specification)

struct LiquidGlassFolderIcon: View {
    let folder: AppFolder
    let apps: [BookmarkedApp]
    let iconSize: CGFloat
    @Binding var isEditMode: Bool
    let isDragging: Bool
    let isDropTarget: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    // Animation states
    @State private var isPressed = false
    @State private var deleteButtonScale: CGFloat = 1.0
    @State private var folderBreathingScale: CGFloat = 1.0
    
    // iOS 26 precise folder specifications
    private var actualFolderSize: CGFloat {
        iconSize * 1.35 // Actual visual size (larger than app icon)
    }
    
    private var cornerRadius: CGFloat {
        actualFolderSize * 0.32 // 32% for folders (more rounded than apps)
    }
    
    private var miniIconSize: CGFloat {
        actualFolderSize * 0.36 // Mini icons in 2x2 grid
    }
    
    private var miniIconSpacing: CGFloat {
        actualFolderSize * 0.055 // Tighter spacing for 2x2
    }
    
    private var shadowRadius: CGFloat {
        isDragging ? 14 : 6 // Deeper shadow for folders
    }
    
    private var shadowY: CGFloat {
        isDragging ? 10 : 4 // More elevation
    }
    
    var body: some View {
        VStack(spacing: 5) { // Match app icon spacing
            // Folder icon container
            ZStack {
                // Shadow layer
                ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.35))
                    .blur(radius: shadowRadius)
                    .offset(y: shadowY)
                    .scaleEffect(0.92)
                    .frame(width: actualFolderSize, height: actualFolderSize)
                
                // Main folder view
                folderIconView
                    .frame(width: actualFolderSize, height: actualFolderSize)
                    .scaleEffect(isPressed ? 0.90 : folderBreathingScale)
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
            .frame(width: iconSize, height: iconSize) // Constrain to grid cell
            .onTapGesture {
                if !isEditMode {
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
            
            // Folder name label
            Text(folder.name)
                .font(.system(size: 11.5, weight: .regular, design: .default))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .frame(width: iconSize + 16, height: 28, alignment: .top)
                .minimumScaleFactor(0.85)
        }
        .opacity(isDragging ? 0.85 : 1.0)
        .scaleEffect(isDropTarget ? 0.78 : 1.0) // More dramatic for folders
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isDropTarget)
        .onAppear {
            // Subtle breathing animation for folders
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                folderBreathingScale = 1.02
            }
        }
    }
    
    @ViewBuilder
    private var folderIconView: some View {
        ZStack {
            // Base folder background with sophisticated glass layers
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    // Base color from folder settings
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: folder.folderColor).opacity(0.3),
                            Color(hex: folder.folderColor).opacity(0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    // Glass material layer
                    ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    // Multi-layer glass effects
                    ZStack {
                        // Layer 1: Primary glass gradient
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white.opacity(0.25), location: 0),
                                .init(color: .white.opacity(0.15), location: 0.3),
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
                                    .init(color: .white.opacity(0.4), location: 0),
                                    .init(color: .white.opacity(0.2), location: 0.3),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: actualFolderSize * 0.4)
                            .blur(radius: 2)
                            
                            Spacer()
                        }
                        
                        // Layer 3: Edge definition
                        ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.2),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    }
                    .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
                )
                .overlay(
                    // Inner shadow for depth
                    ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .blur(radius: 0.5)
                )
            
            // Mini app icons in 2x2 grid
            miniIconsGrid
                .padding(actualFolderSize * 0.16) // Precise padding for 2x2 layout
        }
    }
    
    @ViewBuilder
    private var miniIconsGrid: some View {
        let gridApps = Array(apps.prefix(4)) // Only show 4 apps in 2x2 grid
        
        VStack(spacing: miniIconSpacing) {
            HStack(spacing: miniIconSpacing) {
                // Top left
                Group {
                    if gridApps.count > 0 {
                        miniIcon(for: gridApps[0])
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        emptyMiniIcon
                    }
                }
                
                // Top right
                Group {
                    if gridApps.count > 1 {
                        miniIcon(for: gridApps[1])
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        emptyMiniIcon
                    }
                }
            }
            
            HStack(spacing: miniIconSpacing) {
                // Bottom left
                Group {
                    if gridApps.count > 2 {
                        miniIcon(for: gridApps[2])
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        emptyMiniIcon
                    }
                }
                
                // Bottom right
                Group {
                    if gridApps.count > 3 {
                        miniIcon(for: gridApps[3])
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        emptyMiniIcon
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func miniIcon(for app: BookmarkedApp) -> some View {
        if let iconUrl = app.iconUrl, !iconUrl.isEmpty {
            AsyncImage(url: URL(string: iconUrl)) { phase in
                switch phase {
                case .success(let image):
                    ZStack {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: miniIconSize, height: miniIconSize)
                            .clipShape(ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225))
                        
                        // Mini glass overlay
                        ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white.opacity(0.15), location: 0),
                                        .init(color: .clear, location: 0.5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                case .failure(_), .empty:
                    miniIconPlaceholder(for: app)
                @unknown default:
                    miniIconPlaceholder(for: app)
                }
            }
        } else {
            miniIconPlaceholder(for: app)
        }
    }
    
    @ViewBuilder
    private func miniIconPlaceholder(for app: BookmarkedApp) -> some View {
        ZStack {
            ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors(for: app.name)),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Mini glass overlay
            ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.2), location: 0),
                            .init(color: .clear, location: 0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(app.name.prefix(1).uppercased())
                .font(.system(size: miniIconSize * 0.38, weight: .medium, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: miniIconSize, height: miniIconSize)
    }
    
    @ViewBuilder
    private var emptyMiniIcon: some View {
        ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .frame(width: miniIconSize, height: miniIconSize)
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
                            .strokeBorder(
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
        .offset(x: -10, y: -10) // Adjusted for folder size
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

// Color extension is defined in DesignSystem.swift
