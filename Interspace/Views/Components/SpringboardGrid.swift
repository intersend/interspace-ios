import SwiftUI
import UniformTypeIdentifiers

// MARK: - Springboard Grid Component

struct SpringboardGrid: View {
    @Binding var apps: [BookmarkedApp]
    @Binding var folders: [AppFolder]
    @Binding var isEditMode: Bool
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    let onAddApp: () -> Void
    let viewModel: AppsViewModel
    
    // Grid configuration - iOS standard measurements
    private let columns = 4
    private let rows = 6
    
    // Dynamic sizing based on screen
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    private var iconSize: CGFloat {
        // Calculate based on screen width with proper margins and spacing
        let totalHorizontalSpacing = CGFloat(columns - 1) * horizontalSpacing
        let availableWidth = screenWidth - (2 * sideMargin) - totalHorizontalSpacing
        return availableWidth / CGFloat(columns)
    }
    
    // iOS standard spacing
    private let sideMargin: CGFloat = 27
    private let horizontalSpacing: CGFloat = 27
    private let verticalSpacing: CGFloat = 39
    private let topMargin: CGFloat = 82
    private let bottomMargin: CGFloat = 30
    
    @State private var currentPage: Int? = 0
    @State private var draggedItem: DraggedItem?
    @State private var dropTarget: DropTarget?
    @GestureState private var dragOffset: CGSize = .zero
    @State private var autoScrollTimer: Timer?
    
    // For folder creation
    @State private var pendingFolder: PendingFolder?
    @State private var folderCreationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background tap detector for edit mode
                if isEditMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isEditMode = false
                            }
                            HapticManager.impact(.light)
                        }
                }
                
                VStack(spacing: 0) {
                // No toolbar needed - tap outside to dismiss
                
                // Paged grid view
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0..<numberOfPages, id: \.self) { page in
                            SpringboardPage(
                                items: itemsForPage(page),
                                columns: columns,
                                iconSize: iconSize,
                                horizontalSpacing: horizontalSpacing,
                                verticalSpacing: verticalSpacing,
                                sideMargin: sideMargin,
                                topMargin: topMargin,
                                isEditMode: $isEditMode,
                                draggedItem: $draggedItem,
                                dropTarget: $dropTarget,
                                screenWidth: screenWidth,
                                onAppTap: onAppTap,
                                onFolderTap: onFolderTap,
                                onAddApp: onAddApp,
                                onDragStart: handleDragStart,
                                onDragEnd: handleDragEnd,
                                onDropTargetChange: handleDropTargetChange,
                                viewModel: viewModel
                            )
                            .frame(width: screenWidth)
                        }
                    }
                }
                .scrollDisabled(isEditMode && draggedItem != nil)
                
                Spacer()
                
                // Page indicators
                if numberOfPages > 1 {
                    SpringboardPageIndicator(
                        numberOfPages: numberOfPages,
                        currentPage: currentPage ?? 0
                    )
                    .padding(.bottom, bottomMargin)
                }
                }
            }
        }
        .onAppear {
            if isEditMode {
                HapticManager.impact(.light)
            }
        }
        .onChange(of: isEditMode) { newValue in
            if newValue {
                HapticManager.impact(.light)
            } else {
                HapticManager.impact(.light)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var allItems: [SpringboardItem] {
        var items: [SpringboardItem] = []
        
        // Add apps not in folders
        items.append(contentsOf: apps.filter { $0.folderId == nil }.map { .app($0) })
        
        // Add folders
        items.append(contentsOf: folders.map { .folder($0) })
        
        // Sort by position
        return items.sorted { item1, item2 in
            item1.position < item2.position
        }
    }
    
    private var numberOfPages: Int {
        let itemsPerPage = columns * rows
        let totalItems = allItems.count
        return max(1, (totalItems + itemsPerPage - 1) / itemsPerPage)
    }
    
    private func itemsForPage(_ page: Int) -> [SpringboardItem?] {
        let itemsPerPage = columns * rows
        let startIndex = page * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, allItems.count)
        
        var pageItems: [SpringboardItem?] = []
        
        if startIndex < allItems.count {
            pageItems = Array(allItems[startIndex..<endIndex])
        }
        
        // No plus button in edit mode - it's in the toolbar instead
        
        // Fill remaining slots with empty spaces
        while pageItems.count < itemsPerPage {
            pageItems.append(nil)
        }
        
        return pageItems
    }
    
    // MARK: - Drag and Drop Handlers
    
    private func handleDragStart(_ item: SpringboardItem) {
        HapticManager.impact(.medium)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            draggedItem = DraggedItem(item: item, originalPosition: positionOf(item))
        }
    }
    
    private func handleDragEnd() {
        // Stop auto-scroll timer
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        
        guard let draggedItem = draggedItem else { return }
        
        // Check if we should create a folder
        if let dropTarget = dropTarget,
           case let .item(targetItem) = dropTarget,
           shouldCreateFolder(draggedItem.item, targetItem) {
            createFolder(from: draggedItem.item, and: targetItem)
        } else if let dropTarget = dropTarget {
            // Handle reordering
            performDrop(draggedItem.item, on: dropTarget)
        }
        
        // Reset state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.draggedItem = nil
            self.dropTarget = nil
        }
        
        HapticManager.impact(.light)
    }
    
    private func handleDropTargetChange(_ target: DropTarget?) {
        if dropTarget != target {
            dropTarget = target
            
            // Haptic feedback when hovering over valid drop target
            if target != nil {
                HapticManager.selection()
            }
            
            // Start timer for folder creation hint
            if let target = target,
               case let .item(targetItem) = target,
               let draggedItem = draggedItem,
               shouldCreateFolder(draggedItem.item, targetItem) {
                startFolderCreationTimer()
            } else {
                cancelFolderCreationTimer()
            }
        }
    }
    
    private func shouldCreateFolder(_ item1: SpringboardItem, _ item2: SpringboardItem) -> Bool {
        switch (item1, item2) {
        case (.app, .app):
            return true
        case (.app, .folder), (.folder, .app):
            return true
        default:
            return false
        }
    }
    
    private func createFolder(from item1: SpringboardItem, and item2: SpringboardItem) {
        Task {
            // Get the apps from the items
            var app1: BookmarkedApp?
            var app2: BookmarkedApp?
            
            switch item1 {
            case .app(let app):
                app1 = app
            case .folder:
                // TODO: Handle dragging folder onto app
                return
            }
            
            switch item2 {
            case .app(let app):
                app2 = app
            case .folder:
                // TODO: Handle dragging app onto folder
                return
            }
            
            guard let app1 = app1, let app2 = app2 else { return }
            
            // Create folder with default name
            let folderName = "New Folder"
            let folderColor = "#6366F1" // Default indigo
            
            // Create the folder first
            await viewModel.createFolder(name: folderName, color: folderColor)
            
            // Wait a moment for the folder to be created
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Get the newly created folder (should be the last one)
            guard let newFolder = viewModel.folders.last else { return }
            
            // Move both apps to the new folder
            await viewModel.moveAppToFolder(app1, folderId: newFolder.id, position: 0)
            await viewModel.moveAppToFolder(app2, folderId: newFolder.id, position: 1)
            
            // Haptic feedback for successful folder creation
            HapticManager.notification(.success)
        }
    }
    
    private func performDrop(_ item: SpringboardItem, on target: DropTarget) {
        Task {
            switch target {
            case .position(let targetPosition):
                // Get all items that need to be reordered
                var updatedItems = allItems
                
                // Remove the dragged item from its current position
                guard let currentIndex = updatedItems.firstIndex(where: { $0.id == item.id }) else { return }
                updatedItems.remove(at: currentIndex)
                
                // Insert at new position
                let insertIndex = min(targetPosition, updatedItems.count)
                updatedItems.insert(item, at: insertIndex)
                
                // Update positions for all affected items
                var appIds: [String] = []
                var folderIds: [String] = []
                
                for (_, item) in updatedItems.enumerated() {
                    switch item {
                    case .app(let app):
                        if app.folderId == nil {
                            appIds.append(app.id)
                        }
                    case .folder(let folder):
                        folderIds.append(folder.id)
                    }
                }
                
                // Call the reorder APIs
                if !appIds.isEmpty {
                    await viewModel.reorderApps(appIds)
                }
                if !folderIds.isEmpty {
                    await viewModel.reorderFolders(folderIds)
                }
                
            case .item(_):
                // This is handled by folder creation logic
                break
            }
        }
    }
    
    private func positionOf(_ item: SpringboardItem) -> Int {
        allItems.firstIndex(where: { $0.id == item.id }) ?? 0
    }
    
    private func startFolderCreationTimer() {
        folderCreationTimer?.invalidate()
        folderCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            HapticManager.notification(.success)
        }
    }
    
    private func cancelFolderCreationTimer() {
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil
    }
}

// MARK: - Springboard Item Enum

enum SpringboardItem: Identifiable, Equatable {
    case app(BookmarkedApp)
    case folder(AppFolder)
    
    var id: String {
        switch self {
        case .app(let app):
            return "app_\(app.id)"
        case .folder(let folder):
            return "folder_\(folder.id)"
        }
    }
    
    var position: Int {
        switch self {
        case .app(let app):
            return app.position
        case .folder(let folder):
            return folder.position
        }
    }
}

// MARK: - Dragged Item

struct DraggedItem: Equatable {
    let item: SpringboardItem
    let originalPosition: Int
}

// MARK: - Drop Target

enum DropTarget: Equatable {
    case position(Int)
    case item(SpringboardItem)
}

// MARK: - Pending Folder

struct PendingFolder {
    let item1: SpringboardItem
    let item2: SpringboardItem
}

// MARK: - Springboard Page

struct SpringboardPage: View {
    let items: [SpringboardItem?]
    let columns: Int
    let iconSize: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let sideMargin: CGFloat
    let topMargin: CGFloat
    @Binding var isEditMode: Bool
    @Binding var draggedItem: DraggedItem?
    @Binding var dropTarget: DropTarget?
    let screenWidth: CGFloat
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    let onAddApp: () -> Void
    let onDragStart: (SpringboardItem) -> Void
    let onDragEnd: () -> Void
    let onDropTargetChange: (DropTarget?) -> Void
    let viewModel: AppsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Top margin
            Color.clear.frame(height: topMargin)
            
            // Grid
            VStack(spacing: verticalSpacing) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: horizontalSpacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < items.count {
                                SpringboardCell(
                                    item: items[index],
                                    iconSize: iconSize,
                                    isEditMode: $isEditMode,
                                    isDragging: isDragging(items[index]),
                                    isDropTarget: isDropTarget(items[index]),
                                    onAppTap: onAppTap,
                                    onFolderTap: onFolderTap,
                                    onAddApp: onAddApp,
                                    onDragStart: onDragStart,
                                    onDragEnd: onDragEnd,
                                    onDropTargetChange: onDropTargetChange,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, sideMargin)
            
            Spacer()
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            // Tap on empty space in edit mode dismisses it
            if isEditMode {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditMode = false
                }
                HapticManager.impact(.light)
            }
        }
    }
    
    private func isDragging(_ item: SpringboardItem?) -> Bool {
        guard let item = item else { return false }
        return draggedItem?.item.id == item.id
    }
    
    private func isDropTarget(_ item: SpringboardItem?) -> Bool {
        guard let item = item else { return false }
        if case let .item(targetItem) = dropTarget {
            return targetItem.id == item.id
        }
        return false
    }
}

// MARK: - Springboard Cell

struct SpringboardCell: View {
    let item: SpringboardItem?
    let iconSize: CGFloat
    @Binding var isEditMode: Bool
    let isDragging: Bool
    let isDropTarget: Bool
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    let onAddApp: () -> Void
    let onDragStart: (SpringboardItem) -> Void
    let onDragEnd: () -> Void
    let onDropTargetChange: (DropTarget?) -> Void
    let viewModel: AppsViewModel
    
    @State private var longPressTimer: Timer?
    @GestureState private var dragOffset: CGSize = .zero
    @State private var dragScale: CGFloat = 1.0
    @State private var dragOpacity: Double = 1.0
    
    var body: some View {
        Group {
            if let item = item {
                switch item {
                case .app(let app):
                    LiquidGlassAppIcon(
                        app: app,
                        iconSize: iconSize,
                        isEditMode: $isEditMode,
                        isDragging: isDragging,
                        isDropTarget: isDropTarget,
                        onTap: { onAppTap(app) },
                        onDelete: { viewModel.deleteApp(app) }
                    )
                    .wiggle(isActive: isEditMode && !isDragging)
                    
                case .folder(let folder):
                    LiquidGlassFolderIcon(
                        folder: folder,
                        apps: viewModel.appsInFolder(folder.id),
                        iconSize: iconSize,
                        isEditMode: $isEditMode,
                        isDragging: isDragging,
                        isDropTarget: isDropTarget,
                        onTap: { onFolderTap(folder) },
                        onDelete: { viewModel.deleteFolder(folder) }
                    )
                    .wiggle(isActive: isEditMode && !isDragging)
                }
            } else {
                Color.clear
                    .frame(width: iconSize, height: iconSize + 36) // Account for label space
            }
        }
        .scaleEffect(isDragging ? 1.1 : (isDropTarget ? 0.85 : dragScale))
        .opacity(isDragging ? 0.8 : dragOpacity)
        .shadow(
            color: isDragging ? .black.opacity(0.3) : .clear,
            radius: isDragging ? 10 : 0,
            x: 0,
            y: isDragging ? 5 : 0
        )
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDropTarget)
        .highPriorityGesture(
            isEditMode && item != nil ? dragGesture : nil
        )
        .simultaneousGesture(
            !isEditMode && item != nil ? longPressGesture : nil
        )
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                if let item = item {
                    if !isDragging {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            dragScale = 1.1
                            dragOpacity = 0.9
                        }
                        onDragStart(item)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    dragScale = 1.0
                    dragOpacity = 1.0
                }
                onDragEnd()
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isEditMode = true
                }
                HapticManager.impact(.medium)
            }
    }
}

// MARK: - Page Indicator

struct SpringboardPageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int
    
    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<numberOfPages, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}