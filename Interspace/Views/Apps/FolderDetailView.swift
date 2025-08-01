import SwiftUI

struct FolderDetailView: View {
    let folder: AppFolder
    let apps: [BookmarkedApp]
    @ObservedObject var viewModel: AppsViewModel
    @Binding var isPresented: Bool
    
    @State private var selectedApp: BookmarkedApp?
    @State private var isEditingName = false
    @State private var folderName: String = ""
    @State private var isEditMode = false
    @FocusState private var isNameFieldFocused: Bool
    
    // Animation states
    @State private var animateIn = false
    @State private var backgroundOpacity = 0.0
    @State private var containerScale = 0.85
    @State private var containerOpacity = 0.0
    @State private var iconOpacities: [String: Double] = [:]
    @State private var iconScales: [String: Double] = [:]
    
    // Grid configuration for 3x3 layout
    private let columns = 3
    private let iconSize: CGFloat = 60
    private let spacing: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background with blur effect
            Color.black
                .opacity(0.001) // Nearly invisible but tappable
                .ignoresSafeArea()
                .onTapGesture {
                    if !isEditingName {
                        dismissFolder()
                    }
                }
                .allowsHitTesting(backgroundOpacity > 0.5)
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
            
            // Folder content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 120)
                
                // Folder container
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Folder name
                    if isEditingName {
                        TextField("Folder Name", text: $folderName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($isNameFieldFocused)
                            .onSubmit {
                                saveFolderName()
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .padding(.horizontal, 24)
                    } else {
                        Text(folderName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isEditMode {
                                    startEditingName()
                                }
                            }
                    }
                    
                    // Apps grid
                    LazyVGrid(
                        columns: Array(repeating: SwiftUI.GridItem(.fixed(iconSize), spacing: spacing), count: columns),
                        spacing: spacing
                    ) {
                        ForEach(apps.prefix(9)) { app in // Max 9 apps (3x3)
                            AppIconView(
                                app: app,
                                size: iconSize,
                                editMode: AppEditMode(), // Create local edit mode
                                onTap: {
                                    if !isEditMode {
                                        selectedApp = app
                                    }
                                },
                                onDelete: {
                                    removeAppFromFolder(app)
                                }
                            )
                            .scaleEffect(iconScales[app.id] ?? 0.01)
                            .opacity(iconOpacities[app.id] ?? 0)
                            .allowsHitTesting(animateIn)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
                .frame(width: min(350, UIScreen.main.bounds.width - 32))
                .background(folderBackground)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 20)
                .scaleEffect(containerScale)
                .opacity(containerOpacity)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fullScreenCover(item: $selectedApp) { app in
            WebBrowserView(app: app)
        }
        .onAppear {
            folderName = folder.name
            setupAnimationStates()
            animateOpen()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if !isEditingName {
                enterEditMode()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismissFolder()
                    }
                }
        )
    }
    
    // MARK: - Folder Background
    
    @ViewBuilder
    private var folderBackground: some View {
        ZStack {
            // Base material
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
            
            // Color overlay
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: folder.folderColor).opacity(0.1))
            
            // Border
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        }
    }
    
    // MARK: - Actions
    
    private func setupAnimationStates() {
        for app in apps {
            iconScales[app.id] = 0.01
            iconOpacities[app.id] = 0
        }
    }
    
    private func animateOpen() {
        HapticManager.impact(.light)
        
        // Phase 1: Background blur
        withAnimation(.easeOut(duration: 0.25)) {
            backgroundOpacity = 1.0
        }
        
        // Phase 2: Container appearance
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05)) {
            containerScale = 1.0
            containerOpacity = 1.0
        }
        
        // Phase 3: Icons appear with stagger
        for (index, app) in apps.prefix(9).enumerated() {
            let row = index / columns
            let col = index % columns
            let centerDistance = sqrt(pow(Double(col) - 1, 2) + pow(Double(row) - 1, 2))
            let delay = 0.15 + (centerDistance * 0.03)
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75).delay(delay)) {
                iconScales[app.id] = 1.0
                iconOpacities[app.id] = 1.0
            }
        }
        
        animateIn = true
    }
    
    private func dismissFolder() {
        HapticManager.impact(.light)
        
        // Phase 1: Icons disappear
        for (index, app) in apps.prefix(9).enumerated() {
            let row = index / columns
            let col = index % columns
            let centerDistance = sqrt(pow(Double(col) - 1, 2) + pow(Double(row) - 1, 2))
            let delay = centerDistance * 0.02
            
            withAnimation(.easeIn(duration: 0.2).delay(delay)) {
                iconScales[app.id] = 0.01
                iconOpacities[app.id] = 0
            }
        }
        
        // Phase 2: Container shrinks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.25)) {
                containerScale = 0.85
                containerOpacity = 0
            }
        }
        
        // Phase 3: Background fades
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) {
                backgroundOpacity = 0
            }
        }
        
        // Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isPresented = false
        }
    }
    
    private func enterEditMode() {
        HapticManager.impact(.medium)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = true
        }
    }
    
    private func exitEditMode() {
        HapticManager.impact(.light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = false
            isEditingName = false
        }
    }
    
    private func startEditingName() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditingName = true
            isNameFieldFocused = true
        }
    }
    
    private func saveFolderName() {
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
}

