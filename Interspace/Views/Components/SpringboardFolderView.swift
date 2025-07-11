import SwiftUI

// MARK: - Springboard Folder View (iOS 26)

struct SpringboardFolderView: View {
    let folder: AppFolder
    let apps: [BookmarkedApp]
    let viewModel: AppsViewModel
    
    @Environment(\.dismiss) var dismiss
    @State private var folderName: String = ""
    @State private var isEditingName = false
    @State private var isEditMode = false
    @State private var draggedApp: BookmarkedApp?
    @State private var selectedApp: BookmarkedApp?
    @FocusState private var isNameFieldFocused: Bool
    
    // Animation states
    @State private var animateIn = false
    @State private var backgroundBlur = 0.0
    @State private var containerScale = 0.1
    @State private var containerOpacity = 0.0
    @State private var iconScales: [String: Double] = [:]
    @State private var iconOpacities: [String: Double] = [:]
    
    // Grid configuration for folder - iOS 26 precise
    private let columns = 4
    private let iconSize: CGFloat = 60
    private let horizontalSpacing: CGFloat = 20
    private let verticalSpacing: CGFloat = 24
    private let containerPadding: CGFloat = 28
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(iconSize), spacing: horizontalSpacing), count: columns)
    }
    
    var body: some View {
        ZStack {
            // Enhanced blurred background
            Color.black
                .opacity(0.4 * backgroundBlur)
                .ignoresSafeArea()
                .background(
                    Rectangle()
                        .fill(.ultraThickMaterial)
                        .opacity(backgroundBlur)
                )
                .onTapGesture {
                    if !isEditingName {
                        dismissFolder()
                    }
                }
            
            // Folder content container
            VStack(spacing: 0) {
                // Dynamic top spacing
                Spacer()
                    .frame(height: 100)
                
                // Folder container with enhanced glass
                VStack(spacing: 24) {
                    // Folder name with refined styling
                    folderNameView
                        .padding(.horizontal, 32)
                        .padding(.top, 28)
                    
                    // Apps grid with precise layout
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: gridColumns, spacing: verticalSpacing) {
                            ForEach(apps) { app in
                                LiquidGlassAppIcon(
                                    app: app,
                                    iconSize: iconSize,
                                    isEditMode: $isEditMode,
                                    isDragging: draggedApp?.id == app.id,
                                    isDropTarget: false,
                                    onTap: {
                                        if !isEditMode {
                                            HapticManager.impact(.medium)
                                            selectedApp = app
                                        }
                                    },
                                    onDelete: {
                                        removeAppFromFolder(app)
                                    }
                                )
                                .wiggle(isActive: isEditMode)
                                .scaleEffect(iconScales[app.id] ?? 0.01)
                                .opacity(iconOpacities[app.id] ?? 0)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.75)
                                    .delay(Double(apps.firstIndex(where: { $0.id == app.id }) ?? 0) * 0.02),
                                    value: iconScales[app.id] ?? 0
                                )
                            }
                        }
                        .padding(.horizontal, containerPadding)
                        .padding(.vertical, 24)
                    }
                    .frame(maxHeight: 420)
                }
                .background(
                    // Multi-layer glass construction
                    ZStack {
                        // Base glass
                        ContinuousRoundedRectangle(cornerRadius: 40)
                            .fill(.regularMaterial)
                        
                        // Color overlay from folder
                        ContinuousRoundedRectangle(cornerRadius: 40)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: folder.folderColor).opacity(0.15),
                                        Color(hex: folder.folderColor).opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Glass effects
                        ContinuousRoundedRectangle(cornerRadius: 40)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white.opacity(0.2), location: 0),
                                        .init(color: .white.opacity(0.1), location: 0.2),
                                        .init(color: .clear, location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Border
                        ContinuousRoundedRectangle(cornerRadius: 40)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                    }
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 16)
                .scaleEffect(isEditingName ? 0.96 : (containerScale * (animateIn ? 1 : 0.1)))
                .opacity(containerOpacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditingName)
                
                Spacer()
            }
            
            // No done button needed - tap outside to dismiss edit mode
        }
        .fullScreenCover(item: $selectedApp) { app in
            WebBrowserView(app: app)
        }
        .onAppear {
            folderName = folder.name
            HapticManager.impact(.light)
            animateOpen()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if !isEditingName {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditMode = true
                }
                HapticManager.impact(.medium)
            }
        }
        .onTapGesture {
            if isEditMode && !isEditingName {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditMode = false
                }
                HapticManager.impact(.light)
            }
        }
    }
    
    @ViewBuilder
    private var folderNameView: some View {
        if isEditingName {
            HStack {
                TextField("Folder Name", text: $folderName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        savefolderName()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            // Multi-layer glass effect for text field
                            ContinuousRoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                            
                            ContinuousRoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            ContinuousRoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    Color.white.opacity(0.3),
                                    lineWidth: 0.5
                                )
                        }
                    )
            }
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        } else {
            Text(folderName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditingName = true
                            isNameFieldFocused = true
                        }
                    }
                }
        }
    }
    
    private func savefolderName() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditingName = false
        }
        
        if folderName != folder.name && !folderName.isEmpty {
            Task {
                await viewModel.updateFolder(folder, name: folderName)
            }
        }
    }
    
    private func removeAppFromFolder(_ app: BookmarkedApp) {
        Task {
            await viewModel.moveAppToFolder(app, folderId: nil)
        }
    }
    
    // MARK: - Animation Methods
    
    private func animateOpen() {
        // Initialize icon states
        for app in apps {
            iconScales[app.id] = 0.01
            iconOpacities[app.id] = 0
        }
        
        // Animate background blur
        withAnimation(.easeOut(duration: 0.2)) {
            backgroundBlur = 1.0
        }
        
        // Animate container scale and opacity
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            containerScale = 1.0
            containerOpacity = 1.0
        }
        
        // Animate individual icons with stagger
        for (index, app) in apps.enumerated() {
            withAnimation(
                .spring(response: 0.4, dampingFraction: 0.75)
                .delay(Double(index) * 0.02 + 0.1)
            ) {
                iconScales[app.id] = 1.0
                iconOpacities[app.id] = 1.0
            }
        }
        
        animateIn = true
    }
    
    private func dismissFolder() {
        HapticManager.impact(.light)
        
        // First animate icons out
        for (index, app) in apps.enumerated().reversed() {
            withAnimation(
                .spring(response: 0.3, dampingFraction: 0.8)
                .delay(Double(apps.count - index - 1) * 0.01)
            ) {
                iconScales[app.id] = 0.01
                iconOpacities[app.id] = 0
            }
        }
        
        // Then animate container
        withAnimation(
            .spring(response: 0.4, dampingFraction: 0.8)
            .delay(Double(apps.count) * 0.01 + 0.05)
        ) {
            containerScale = 0.1
            containerOpacity = 0
        }
        
        // Finally fade out background and dismiss
        withAnimation(
            .easeIn(duration: 0.2)
            .delay(Double(apps.count) * 0.01 + 0.2)
        ) {
            backgroundBlur = 0
        }
        
        // Dismiss after animations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(apps.count) * 0.01) {
            dismiss()
        }
    }
}

// MARK: - Clear Background Helper

struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
