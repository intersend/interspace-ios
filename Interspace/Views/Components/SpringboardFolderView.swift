import SwiftUI

// MARK: - Springboard Folder View

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
    
    // Grid configuration for folder - matches iOS
    private let columns = Array(repeating: SwiftUI.GridItem(.flexible(), spacing: 20), count: 4)
    private let iconSize: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Blurred background
            Color.black
                .opacity(0.4)
                .ignoresSafeArea()
                .background(.ultraThickMaterial)
                .onTapGesture {
                    if !isEditingName {
                        dismiss()
                    }
                }
            
            // Folder content container
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: 120)
                
                // Folder container
                VStack(spacing: 20) {
                    // Folder name
                    folderNameView
                        .padding(.horizontal, 40)
                    
                    // Apps grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 35) {
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
                            }
                            
                            // No plus button in folder edit mode
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                    }
                    .frame(maxHeight: 400)
                }
                .background(
                    ContinuousRoundedRectangle(cornerRadius: 38)
                        .fill(.regularMaterial)
                        .overlay(
                            ContinuousRoundedRectangle(cornerRadius: 38)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 20)
                .scaleEffect(isEditingName ? 0.95 : 1.0)
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
        }
        .onLongPressGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditMode = true
            }
            HapticManager.impact(.medium)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ContinuousRoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
            }
        } else {
            Text(folderName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
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