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
    
    // Grid configuration - iOS 26 precise measurements
    private let columns = 4
    private let rows = 6
    
    // Dynamic sizing based on screen
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    // Calculate total cell height for proper vertical spacing
    private var cellHeight: CGFloat {
        iconSize + labelHeight + labelToIconSpacing
    }
    
    // Calculate total grid height
    private var gridHeight: CGFloat {
        let rows: CGFloat = 6
        return (cellHeight * rows) + (verticalSpacing * (rows - 1))
    }
    
    private var iconSize: CGFloat {
        // iOS standard: exactly 60pt on all iPhones
        return 60
    }
    
    // iOS exact spacing specifications
    private var sideMargin: CGFloat {
        // Standard iOS margin: 27pt on most models
        if screenWidth >= 428 { // Pro Max models
            return 34
        } else if screenWidth >= 390 { // Pro models
            return 27
        } else { // Standard models
            return 24
        }
    }
    
    private var horizontalSpacing: CGFloat {
        // Calculated to fit 4 icons perfectly with proper spacing
        let totalIconWidth = iconSize * CGFloat(columns)
        let availableSpace = screenWidth - (2 * sideMargin) - totalIconWidth
        let spacing = availableSpace / CGFloat(columns - 1)
        // Ensure minimum spacing of 16pt to prevent icons from touching
        return max(spacing, 16)
    }
    
    private let verticalSpacing: CGFloat = 24 // iOS standard vertical spacing between rows
    private let topMargin: CGFloat = 14 // Small top margin since NavigationBar provides space
    private let bottomMargin: CGFloat = 30
    
    // Label specifications - iOS standard
    private let labelHeight: CGFloat = 28 // Two lines of text with proper line height
    private let labelToIconSpacing: CGFloat = 5 // Standard iOS spacing between icon and label
    
    @State private var currentPage: Int = 0
    @State private var draggedItem: DraggedItem?
    @State private var dropTarget: DropTarget?
    @State private var activeDropZone: CGRect?
    @GestureState private var dragOffset: CGSize = .zero
    @State private var autoScrollTimer: Timer?
    
    // Enhanced folder creation
    @State private var pendingFolder: PendingFolder?
    @State private var folderCreationTimer: Timer?
    @State private var folderCreationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background tap detector for edit mode
                if isEditMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // End edit mode with refined animation
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isEditMode = false
                            }
                            HapticManager.impact(.light)
                        }
                }
                
                VStack(spacing: 0) {
                    // Paged grid view using TabView for native paging
                    TabView(selection: $currentPage) {
                        ForEach(0..<numberOfPages, id: \.self) { page in
                            SpringboardPage(
                                items: itemsForPage(page),
                                columns: columns,
                                iconSize: iconSize,
                                horizontalSpacing: horizontalSpacing,
                                verticalSpacing: verticalSpacing,
                                sideMargin: sideMargin,
                                topMargin: topMargin,
                                labelHeight: labelHeight,
                                labelSpacing: labelToIconSpacing,
                                isEditMode: $isEditMode,
                                draggedItem: $draggedItem,
                                dropTarget: $dropTarget,
                                folderCreationProgress: $folderCreationProgress,
                                screenWidth: screenWidth,
                                onAppTap: onAppTap,
                                onFolderTap: onFolderTap,
                                onAddApp: onAddApp,
                                onDragStart: handleDragStart,
                                onDragEnd: handleDragEnd,
                                onDropTargetChange: handleDropTargetChange,
                                viewModel: viewModel
                            )
                            .tag(page)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .disabled(isEditMode && draggedItem != nil)
                    .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85), value: currentPage)
                    
                    // Page indicators with iOS 26 styling
                    if numberOfPages > 1 {
                        SpringboardPageIndicator(
                            numberOfPages: numberOfPages,
                            currentPage: currentPage
                        )
                        .padding(.bottom, 34) // Standard iOS padding from bottom
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                
                // Folder creation hint overlay
                if let pendingFolder = pendingFolder, folderCreationProgress > 0 {
                    FolderCreationHint(
                        progress: folderCreationProgress,
                        sourceItem: pendingFolder.item1,
                        targetItem: pendingFolder.item2
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                if isEditMode {
                    startEditModeHaptics()
                }
            }
            .onChange(of: isEditMode) { newValue in
                if newValue {
                    startEditModeHaptics()
                } else {
                    endEditModeHaptics()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var allItems: [SpringboardItem] {
        var items: [SpringboardItem] = []
        
        // Add apps not in folders
        let unfolderedApps = apps.filter { $0.folderId == nil }
        print("🎯 SpringboardGrid: Found \(unfolderedApps.count) unfoldered apps out of \(apps.count) total apps")
        items.append(contentsOf: unfolderedApps.map { .app($0) })
        
        // Add folders
        items.append(contentsOf: folders.map { .folder($0) })
        
        // Sort by position
        let sortedItems = items.sorted { item1, item2 in
            item1.position < item2.position
        }
        print("🎯 SpringboardGrid: Displaying \(sortedItems.count) total items")
        return sortedItems
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
        
        print("📄 SpringboardGrid: Page \(page) has \(pageItems.count) items")
        
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
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
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
        
        // Reset state with refined animation
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            self.draggedItem = nil
            self.dropTarget = nil
            self.folderCreationProgress = 0
            self.pendingFolder = nil
        }
        
        HapticManager.impact(.light)
    }
    
    private func handleDropTargetChange(_ target: DropTarget?) {
        if dropTarget != target {
            dropTarget = target
            
            // Enhanced haptic feedback
            if target != nil {
                HapticManager.selection()
            }
            
            // Folder creation hint with progress
            if let target = target,
               case let .item(targetItem) = target,
               let draggedItem = draggedItem,
               shouldCreateFolder(draggedItem.item, targetItem) {
                pendingFolder = PendingFolder(item1: draggedItem.item, item2: targetItem)
                startFolderCreationTimer()
            } else {
                cancelFolderCreationTimer()
                withAnimation(.easeOut(duration: 0.2)) {
                    folderCreationProgress = 0
                    pendingFolder = nil
                }
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func startEditModeHaptics() {
        // Initial impact
        HapticManager.impact(.light)
        
        // Subtle continuous feedback could be added here
        // But iOS typically doesn't use continuous haptics
    }
    
    private func endEditModeHaptics() {
        HapticManager.impact(.light)
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
        
        // Animate progress
        withAnimation(.linear(duration: 0.5)) {
            folderCreationProgress = 1.0
        }
        
        folderCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            HapticManager.notification(.success)
            // Additional visual feedback for folder creation readiness
            withAnimation(.easeInOut(duration: 0.15).repeatCount(2, autoreverses: true)) {
                folderCreationProgress = 0.8
            }
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
    let labelHeight: CGFloat
    let labelSpacing: CGFloat
    @Binding var isEditMode: Bool
    @Binding var draggedItem: DraggedItem?
    @Binding var dropTarget: DropTarget?
    @Binding var folderCreationProgress: CGFloat
    let screenWidth: CGFloat
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    let onAddApp: () -> Void
    let onDragStart: (SpringboardItem) -> Void
    let onDragEnd: () -> Void
    let onDropTargetChange: (DropTarget?) -> Void
    let viewModel: AppsViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Add top padding to properly position the grid
                Spacer()
                    .frame(height: 10) // Additional spacing to match iOS springboard (total 24pt with topMargin)
                
                // Grid with proper spacing
                VStack(spacing: verticalSpacing) {
                    ForEach(0..<6, id: \.self) { row in
                        HStack(spacing: horizontalSpacing) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < items.count {
                                    SpringboardCell(
                                        item: items[index],
                                        iconSize: iconSize,
                                        labelHeight: labelHeight,
                                        labelToIconSpacing: labelSpacing,
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
                                    .onAppear {
                                        if let item = items[index] {
                                            print("📦 SpringboardCell appeared for item at index \(index)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, sideMargin)
                
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
    let labelHeight: CGFloat
    let labelToIconSpacing: CGFloat
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
    @State private var dragRotation: Double = 0
    
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
                    .frame(width: iconSize, height: iconSize + labelHeight + labelToIconSpacing)
            }
        }
        .scaleEffect(isDragging ? 1.15 : (isDropTarget ? 0.82 : dragScale))
        .rotationEffect(.degrees(isDragging ? dragRotation : 0))
        .opacity(isDragging ? 0.85 : dragOpacity)
        .shadow(
            color: isDragging ? .black.opacity(0.35) : .clear,
            radius: isDragging ? 12 : 0,
            x: 0,
            y: isDragging ? 8 : 0
        )
        .offset(dragOffset)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isDragging)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isDropTarget)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragScale)
        .highPriorityGesture(
            isEditMode && item != nil ? dragGesture : nil
        )
        .simultaneousGesture(
            !isEditMode && item != nil ? longPressGesture : nil
        )
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                if let item = item {
                    if !isDragging {
                        // Enhanced lift animation
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                            dragScale = 1.15
                            dragOpacity = 0.85
                            // Slight rotation based on drag direction
                            dragRotation = value.translation.width / 50
                        }
                        onDragStart(item)
                    } else {
                        // Update rotation during drag
                        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                            dragRotation = value.translation.width / 50
                            dragRotation = max(-3, min(3, dragRotation)) // Limit rotation
                        }
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                    dragScale = 1.0
                    dragOpacity = 1.0
                    dragRotation = 0
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
        HStack(spacing: 7) {
            ForEach(0..<numberOfPages, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.white : Color.white.opacity(0.35))
                    .frame(width: page == currentPage ? 8 : 7, height: page == currentPage ? 8 : 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.black.opacity(0.15))
                )
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

// MARK: - Folder Creation Hint

struct FolderCreationHint: View {
    let progress: CGFloat
    let sourceItem: SpringboardItem
    let targetItem: SpringboardItem
    
    var body: some View {
        GeometryReader { geometry in
            if progress > 0 {
                // Visual hint overlay
                ZStack {
                    // Pulsing circle around target
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6 * progress),
                                    Color.white.opacity(0.3 * progress)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 90 * progress, height: 90 * progress)
                        .blur(radius: 1)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // Progress indicator
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.white.opacity(0.8),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .animation(.linear, value: progress)
            }
        }
    }
}