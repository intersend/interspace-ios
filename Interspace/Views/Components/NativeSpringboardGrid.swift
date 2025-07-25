import SwiftUI
import UIKit

// MARK: - Native Springboard Grid

struct NativeSpringboardGrid: View {
    @Binding var apps: [BookmarkedApp]
    @Binding var folders: [AppFolder]
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    let onAddApp: () -> Void
    let viewModel: AppsViewModel
    @EnvironmentObject var stateManager: SpringboardStateManager
    
    @State private var currentPage: Int = 0
    
    var body: some View {
        ZStack {
            // Main grid using UICollectionView
            SpringboardCollectionView(
                apps: $apps,
                folders: $folders,
                stateManager: stateManager,
                viewModel: viewModel,
                onAppTap: onAppTap,
                onFolderTap: onFolderTap
            )
            .ignoresSafeArea(edges: .horizontal)
            
            // Drag overlay is now handled within UICollectionView
            
            // Page indicators
            VStack {
                Spacer()
                if numberOfPages > 1 {
                    SpringboardPageControl(
                        numberOfPages: numberOfPages,
                        currentPage: $currentPage
                    )
                    .padding(.bottom, 34)
                }
            }
        }
        .onChange(of: stateManager.mode) { mode in
            handleModeChange(mode)
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Data Management
    
    private var allItems: [SpringboardItem] {
        var items: [SpringboardItem] = []
        
        // Add apps not in folders
        let unfolderedApps = apps.filter { $0.folderId == nil }
        items.append(contentsOf: unfolderedApps.map { .app($0) })
        
        // Add folders
        items.append(contentsOf: folders.map { .folder($0) })
        
        // Sort by position
        return items.sorted { $0.position < $1.position }
    }
    
    private var numberOfPages: Int {
        let itemsPerPage = 24 // 6 rows × 4 columns
        // This needs proper calculation accounting for 2x2 folders
        return max(1, (allItems.count + itemsPerPage - 1) / itemsPerPage)
    }
    
    private func itemsForPage(_ page: Int) -> [SpringboardItem?] {
        // Simplified for now - needs proper 2x2 folder grid calculation
        let itemsPerPage = 24
        let startIndex = page * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, allItems.count)
        
        var pageItems: [SpringboardItem?] = []
        if startIndex < allItems.count {
            pageItems = Array(allItems[startIndex..<endIndex])
        }
        
        // Fill remaining with nil
        while pageItems.count < itemsPerPage {
            pageItems.append(nil)
        }
        
        return pageItems
    }
    
    // MARK: - State Management
    
    private func setupInitialState() {
        // Register all items
        for item in allItems {
            stateManager.registerIcon(id: item.id)
        }
    }
    
    private func handleModeChange(_ mode: SpringboardStateManager.Mode) {
        // Mode changes are now handled internally by UICollectionView
        // The dragging visualization is managed by the collection view's gesture recognizers
    }
}

struct SpringboardPageControl: View {
    let numberOfPages: Int
    @Binding var currentPage: Int
    
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<numberOfPages, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.white : Color.white.opacity(0.35))
                    .frame(width: page == currentPage ? 8 : 7, height: page == currentPage ? 8 : 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                    .onTapGesture {
                        currentPage = page
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}