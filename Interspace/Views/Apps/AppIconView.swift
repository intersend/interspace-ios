import SwiftUI

struct AppIconView: View {
    let app: BookmarkedApp
    let size: CGFloat
    @ObservedObject var editMode: AppEditMode
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0
    
    // iOS standard corner radius is 22.5% of icon size
    private var cornerRadius: CGFloat {
        size * 0.225
    }
    
    private var isMorphing: Bool {
        editMode.morphingAppIds.contains(app.id)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Icon
            ZStack {
                // App icon
                AppIconImage(app: app, size: size, cornerRadius: cornerRadius)
                    .scaleEffect(isPressed ? 0.92 : (isMorphing ? 0.8 : 1.0))
                    .opacity(isMorphing ? 0.8 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isMorphing)
                
                // Morphing overlay effect
                if isMorphing {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size/2
                            )
                        )
                        .frame(width: size * 1.2, height: size * 1.2)
                        .blur(radius: 4)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isMorphing)
                }
                
                // Delete badge
                if editMode.shouldShowDeleteBadge(for: app.id) && !isMorphing {
                    DeleteBadge(onDelete: onDelete)
                        .offset(x: -size/2 + 2, y: -size/2 + 2)
                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isMorphing ? 0 : wiggleAngle))
            .offset(y: isMorphing ? -5 : 0)
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !editMode.isEditing {
                    editMode.enterEditMode()
                }
            }
            
            // App name
            Text(app.name)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: size + 16, alignment: .top)
                .opacity(isMorphing ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isMorphing)
        }
        .onAppear {
            startWiggleIfNeeded()
        }
        .onChange(of: editMode.wiggleAnimation) { _ in
            startWiggleIfNeeded()
        }
    }
    
    private func handleTap() {
        guard !editMode.isEditing else { return }
        
        isPressed = true
        HapticManager.impact(.light)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
            onTap()
        }
    }
    
    private func startWiggleIfNeeded() {
        if editMode.shouldWiggle(for: app.id) {
            // Subtle wiggle animation - iOS style
            withAnimation(
                .linear(duration: 0.13)
                .repeatForever(autoreverses: true)
            ) {
                wiggleAngle = 2 // 2 degrees rotation
            }
        } else {
            withAnimation(.default) {
                wiggleAngle = 0
            }
        }
    }
}

// MARK: - App Icon Image

struct AppIconImage: View {
    let app: BookmarkedApp
    let size: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        if let iconUrl = app.iconUrl, !iconUrl.isEmpty {
            AsyncImage(url: URL(string: iconUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        
                case .empty, .failure:
                    PlaceholderIcon(name: app.name, size: size, cornerRadius: cornerRadius)
                    
                @unknown default:
                    PlaceholderIcon(name: app.name, size: size, cornerRadius: cornerRadius)
                }
            }
        } else {
            PlaceholderIcon(name: app.name, size: size, cornerRadius: cornerRadius)
        }
    }
}

// MARK: - Placeholder Icon

struct PlaceholderIcon: View {
    let name: String
    let size: CGFloat
    let cornerRadius: CGFloat
    
    private var gradientColors: [Color] {
        let hash = abs(name.hashValue)
        let colorIndex = hash % 6
        
        let colorPairs: [[Color]] = [
            [Color(red: 0.39, green: 0.58, blue: 1.0), Color(red: 0.25, green: 0.45, blue: 0.95)], // Blue
            [Color(red: 1.0, green: 0.38, blue: 0.29), Color(red: 0.95, green: 0.25, blue: 0.18)], // Red
            [Color(red: 0.35, green: 0.84, blue: 0.39), Color(red: 0.25, green: 0.75, blue: 0.30)], // Green
            [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 0.95, green: 0.48, blue: 0.0)], // Orange
            [Color(red: 0.69, green: 0.32, blue: 0.87), Color(red: 0.59, green: 0.22, blue: 0.77)], // Purple
            [Color(red: 1.0, green: 0.21, blue: 0.55), Color(red: 0.90, green: 0.11, blue: 0.45)] // Pink
        ]
        
        return colorPairs[colorIndex]
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Delete Badge

struct DeleteBadge: View {
    let onDelete: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.notification(.warning)
            isPressed = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onDelete()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.3).opacity(0.9))
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.8 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
    }
}

// MARK: - Folder Icon View

struct FolderIconView: View {
    let folder: AppFolder
    let apps: [BookmarkedApp]
    let size: CGFloat
    @ObservedObject var editMode: AppEditMode
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 4) {
            // Folder icon
            ZStack {
                // Folder background - Apple style blur effect
                ZStack {
                    // Base blur background
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: size, height: size)
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)
                }
                
                // Mini app icons (2x2 grid)
                VStack(spacing: size * 0.05) {
                    ForEach(0..<2) { row in
                        HStack(spacing: size * 0.05) {
                            ForEach(0..<2) { col in
                                let index = row * 2 + col
                                if index < apps.count {
                                    MiniAppIcon(app: apps[index], size: size * 0.38)
                                } else {
                                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: size * 0.38, height: size * 0.38)
                                }
                            }
                        }
                    }
                }
                .padding(size * 0.1) // Add padding inside folder
                
                // Delete badge
                if editMode.shouldShowDeleteBadge(for: folder.id) {
                    DeleteBadge(onDelete: onDelete)
                        .offset(x: -size/2 + 2, y: -size/2 + 2)
                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
            .rotationEffect(.degrees(wiggleAngle))
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if !editMode.isEditing {
                    editMode.enterEditMode()
                }
            }
            
            // Folder name
            Text(folder.name)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: size + 16, alignment: .top)
        }
        .onAppear {
            startWiggleIfNeeded()
        }
        .onChange(of: editMode.wiggleAnimation) { _ in
            startWiggleIfNeeded()
        }
    }
    
    private func handleTap() {
        guard !editMode.isEditing else { return }
        
        isPressed = true
        HapticManager.impact(.light)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
            onTap()
        }
    }
    
    private func startWiggleIfNeeded() {
        if editMode.shouldWiggle(for: folder.id) {
            withAnimation(
                .linear(duration: 0.13)
                .repeatForever(autoreverses: true)
            ) {
                wiggleAngle = 2
            }
        } else {
            withAnimation(.default) {
                wiggleAngle = 0
            }
        }
    }
}

// MARK: - Mini App Icon

struct MiniAppIcon: View {
    let app: BookmarkedApp
    let size: CGFloat
    
    var body: some View {
        if let iconUrl = app.iconUrl, !iconUrl.isEmpty {
            AsyncImage(url: URL(string: iconUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                        
                case .empty, .failure:
                    MiniPlaceholderIcon(name: app.name, size: size)
                    
                @unknown default:
                    MiniPlaceholderIcon(name: app.name, size: size)
                }
            }
        } else {
            MiniPlaceholderIcon(name: app.name, size: size)
        }
    }
}

struct MiniPlaceholderIcon: View {
    let name: String
    let size: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
            .fill(Color.white.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            )
    }
}