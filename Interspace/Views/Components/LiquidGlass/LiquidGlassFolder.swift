import SwiftUI

// MARK: - Liquid Glass Folder Icon

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
    
    // Folder specifications
    private var folderSize: CGFloat {
        iconSize * 2.2 // Folder is 2.2x app icon size
    }
    
    private var cornerRadius: CGFloat {
        folderSize * 0.35 // More rounded for folders
    }
    
    private var miniIconSize: CGFloat {
        folderSize * 0.35 // Mini icons in 2x2 grid
    }
    
    private var miniIconSpacing: CGFloat {
        folderSize * 0.08
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Folder icon
            folderIconView
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
                        HapticManager.impact(.light)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                isPressed = false
                            }
                            onTap()
                        }
                    }
                }
            
            // Folder name
            Text(folder.name)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: iconSize + 12, height: 28, alignment: .top)
                .minimumScaleFactor(0.8)
        }
        .opacity(isDragging ? 0.8 : 1.0)
        .scaleEffect(isDropTarget ? 0.85 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDropTarget)
    }
    
    @ViewBuilder
    private var folderIconView: some View {
        ZStack {
            // Glass background with folder color
            ContinuousRoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    // Folder color overlay
                    Color(hex: folder.folderColor)
                        .opacity(0.2)
                        .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
                )
                .overlay(
                    // Glass effects
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(ContinuousRoundedRectangle(cornerRadius: cornerRadius))
                )
                .glassLayer(cornerRadius: cornerRadius)
                .shadow(
                    color: .black.opacity(0.25),
                    radius: 5,
                    x: 0,
                    y: 2.5
                )
            
            // Mini app icons grid
            miniIconsGrid
        }
        .frame(width: iconSize, height: iconSize)
    }
    
    @ViewBuilder
    private var miniIconsGrid: some View {
        let gridApps = Array(apps.prefix(4))
        
        VStack(spacing: miniIconSpacing) {
            HStack(spacing: miniIconSpacing) {
                // Top left
                if gridApps.count > 0 {
                    miniIcon(for: gridApps[0])
                } else {
                    emptyMiniIcon
                }
                
                // Top right
                if gridApps.count > 1 {
                    miniIcon(for: gridApps[1])
                } else {
                    emptyMiniIcon
                }
            }
            
            HStack(spacing: miniIconSpacing) {
                // Bottom left
                if gridApps.count > 2 {
                    miniIcon(for: gridApps[2])
                } else {
                    emptyMiniIcon
                }
                
                // Bottom right
                if gridApps.count > 3 {
                    miniIcon(for: gridApps[3])
                } else {
                    emptyMiniIcon
                }
            }
        }
        .padding(miniIconSpacing * 1.5)
    }
    
    @ViewBuilder
    private func miniIcon(for app: BookmarkedApp) -> some View {
        if let iconUrl = app.iconUrl, !iconUrl.isEmpty {
            AsyncImage(url: URL(string: iconUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: miniIconSize, height: miniIconSize)
                        .clipShape(ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225))
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
            
            Text(app.name.prefix(1).uppercased())
                .font(.system(size: miniIconSize * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: miniIconSize, height: miniIconSize)
    }
    
    @ViewBuilder
    private var emptyMiniIcon: some View {
        ContinuousRoundedRectangle(cornerRadius: miniIconSize * 0.225)
            .fill(Color.white.opacity(0.1))
            .frame(width: miniIconSize, height: miniIconSize)
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
                        Circle()
                            .fill(Color(red: 1, green: 0.231, blue: 0.188))
                            .frame(width: 24, height: 24)
                        
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

// Color extension is defined in DesignSystem.swift