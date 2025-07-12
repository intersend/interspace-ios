import SwiftUI
import UniformTypeIdentifiers

struct AppsView: View {
    @StateObject private var viewModel = AppsViewModel()
    @State private var isEditMode = false
    @State private var selectedApp: BookmarkedApp?
    @State private var selectedFolder: AppFolder?
    @State private var showSettings = false
    @State private var showUniversalAddTray = false
    @State private var showAbout = false
    @State private var showSecurity = false
    @State private var showNotifications = false
    
    var body: some View {
        ZStack {
            // Native iPhone-style pure black background
            Color(uiColor: UIColor.black)
                .ignoresSafeArea(.all)
            
            if viewModel.apps.isEmpty && viewModel.folders.isEmpty && !viewModel.isLoading {
                emptyStateView
                    .onAppear {
                        print("🎯 AppsView: Showing empty state")
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Main springboard grid - fills entire available space
                SpringboardGrid(
                    apps: $viewModel.apps,
                    folders: $viewModel.folders,
                    isEditMode: $isEditMode,
                    onAppTap: handleAppTap,
                    onFolderTap: handleFolderTap,
                    onAddApp: {
                        showUniversalAddTray = true
                    },
                    viewModel: viewModel
                )
                .onAppear {
                    print("🎯 AppsView: SpringboardGrid appeared with \(viewModel.apps.count) apps")
                }
            }
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            
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
        .sheet(isPresented: $showUniversalAddTray) {
            UniversalAddTray(isPresented: $showUniversalAddTray, initialSection: .app, appsViewModel: viewModel)
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
        .onChange(of: viewModel.apps) { newApps in
            print("🎯 AppsView: Apps changed, count: \(newApps.count)")
            print("🎯 AppsView: isLoading: \(viewModel.isLoading), isEmpty check: apps=\(viewModel.apps.isEmpty), folders=\(viewModel.folders.isEmpty)")
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            print("🎯 AppsView: isLoading changed to: \(isLoading)")
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
    var emptyStateView: some View {
        VStack {
            Spacer()
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
            }
            .padding(.horizontal, 40)
            Spacer()
        }
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

// MARK: - Status Bar Style Modifier

struct StatusBarStyleModifier: ViewModifier {
    let style: UIStatusBarStyle
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if #available(iOS 13.0, *) {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first else { return }
                    
                    window.overrideUserInterfaceStyle = style == .lightContent ? .dark : .light
                }
            }
    }
}

extension View {
    func statusBarStyle(_ style: UIStatusBarStyle) -> some View {
        modifier(StatusBarStyleModifier(style: style))
    }
}

struct AppsView_Previews: PreviewProvider {
    static var previews: some View {
        AppsView()
            .preferredColorScheme(.dark)
    }
}
