import SwiftUI

struct AppsView: View {
    @StateObject private var viewModel = AppsViewModel()
    @StateObject private var editMode = AppEditMode()
    
    // Sheet states
    @State private var showUniversalAddTray = false
    @State private var showAbout = false
    @State private var showSecurity = false
    @State private var showNotifications = false
    @State private var selectedApp: BookmarkedApp?
    @State private var selectedFolder: AppFolder?
    
    var body: some View {
        ZStack {
            // Pure black background consistent with other views
            Color.black
                .ignoresSafeArea()
            
            if viewModel.apps.isEmpty && viewModel.folders.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                AppsGridView(
                    apps: $viewModel.apps,
                    folders: $viewModel.folders,
                    editMode: editMode,
                    viewModel: viewModel,
                    onAppTap: handleAppTap,
                    onFolderTap: handleFolderTap
                )
            }
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if editMode.isEditing {
                    Button("Done") {
                        editMode.exitEditMode()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                } else {
                    StandardToolbarButtons(
                        showUniversalAddTray: $showUniversalAddTray,
                        showAbout: $showAbout,
                        showSecurity: $showSecurity,
                        showNotifications: $showNotifications,
                        initialSection: .app
                    )
                }
            }
        }
        .sheet(isPresented: $showUniversalAddTray) {
            UniversalAddTray(
                isPresented: $showUniversalAddTray,
                initialSection: .app,
                appsViewModel: viewModel
            )
            .presentationDetents([.height(UIScreen.main.bounds.height * 0.95)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showAbout) {
            ProfileAboutView()
        }
        .sheet(isPresented: $showSecurity) {
            ProfileSecurityView()
        }
        .sheet(isPresented: $showNotifications) {
            ProfileNotificationsView()
        }
        .fullScreenCover(item: $selectedApp) { app in
            WebBrowserView(app: app)
        }
        .overlay(
            selectedFolder.map { folder in
                FolderDetailView(
                    folder: folder,
                    apps: viewModel.appsInFolder(folder.id),
                    viewModel: viewModel,
                    isPresented: Binding(
                        get: { selectedFolder != nil },
                        set: { if !$0 { selectedFolder = nil } }
                    )
                )
            }
        )
        .onAppear {
            Task {
                await viewModel.loadApps()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Text
                VStack(spacing: 8) {
                    Text("Welcome to Your Apps")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Add your favorite Web3 apps and organize them for quick access")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Add button
                Button(action: {
                    HapticManager.impact(.medium)
                    showUniversalAddTray = true
                }) {
                    Text("Add Your First App")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Handlers
    
    private func handleAppTap(_ app: BookmarkedApp) {
        if !editMode.isEditing {
            HapticManager.impact(.light)
            selectedApp = app
        }
    }
    
    private func handleFolderTap(_ folder: AppFolder) {
        if !editMode.isEditing {
            HapticManager.impact(.light)
            selectedFolder = folder
        }
    }
}

// MARK: - Preview

struct AppsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppsView()
        }
        .preferredColorScheme(.dark)
    }
}