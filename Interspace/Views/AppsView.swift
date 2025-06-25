import SwiftUI
import UniformTypeIdentifiers

struct AppsView: View {
    @StateObject private var viewModel = AppsViewModel()
    @State private var isEditMode = false
    @State private var showAddApp = false
    @State private var selectedApp: BookmarkedApp?
    @State private var selectedFolder: AppFolder?
    @State private var showSettings = false
    @State private var showUniversalAddTray = false
    @State private var showAbout = false
    @State private var showSecurity = false
    @State private var showNotifications = false
    
    var body: some View {
        NavigationStack {
            ZStack {
            // Native iPhone-style background
            Color.black
                .ignoresSafeArea(.all)
            
            if viewModel.apps.isEmpty && viewModel.folders.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                // Main springboard grid
                SpringboardGrid(
                    apps: $viewModel.apps,
                    folders: $viewModel.folders,
                    isEditMode: $isEditMode,
                    onAppTap: handleAppTap,
                    onFolderTap: handleFolderTap,
                    onAddApp: {
                        showAddApp = true
                    },
                    viewModel: viewModel
                )
            }
            
            // Loading overlay
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            }
            .navigationBarTitle("Apps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            UniversalAddTray(isPresented: $showUniversalAddTray, initialSection: .app)
        }
        .sheet(isPresented: $showAbout) {
            ProfileAboutView()
        }
        .sheet(isPresented: $showSecurity) {
            ProfileSecurityView(showDeleteConfirmation: .constant(false))
        }
        .sheet(isPresented: $showNotifications) {
            ProfileNotificationsView()
        }
        .fullScreenCover(item: $selectedFolder) { folder in
            SpringboardFolderView(
                folder: folder,
                apps: viewModel.appsInFolder(folder.id),
                viewModel: viewModel
            )
            .background(ClearBackground())
        }
        .fullScreenCover(item: $selectedApp) { app in
            WebBrowserView(app: app)
                .interactiveDismiss(isPresented: .init(
                    get: { selectedApp != nil },
                    set: { if !$0 { selectedApp = nil } }
                ))
        }
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
        .sheet(isPresented: $showSettings) {
            // Settings view to be implemented
            Text("Settings")
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            // Content at top
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Empty state with glass effect
                VStack(spacing: DesignTokens.Spacing.lg) {
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
                    
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Text("Welcome to Your Apps")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Add your favorite Web3 apps and organize them into folders for quick access")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Button(action: {
                        HapticManager.impact(.medium)
                        showAddApp = true
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
                }
                .padding(.horizontal, 40)
                .padding(.top, 120)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Methods
    
    private func handleAppTap(_ app: BookmarkedApp) {
        if !isEditMode {
            HapticManager.impact(.medium)
            selectedApp = app
        }
    }
    
    private func handleFolderTap(_ folder: AppFolder) {
        if !isEditMode {
            HapticManager.impact(.light)
            selectedFolder = folder
        }
    }
}


// MARK: - Preview

struct AppsView_Previews: PreviewProvider {
    static var previews: some View {
        AppsView()
            .preferredColorScheme(.dark)
    }
}