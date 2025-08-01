import SwiftUI

struct AppsGridView: View {
    @Binding var apps: [BookmarkedApp]
    @Binding var folders: [AppFolder]
    @ObservedObject var editMode: AppEditMode
    @ObservedObject var viewModel: AppsViewModel
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    
    // Folder deletion confirmation
    @State private var folderToDelete: AppFolder?
    @State private var showDeleteFolderAlert = false
    
    // Grid configuration
    private let columns = 4
    private let horizontalPadding: CGFloat = 16
    private let verticalSpacing: CGFloat = 32
    private let horizontalSpacing: CGFloat = 16
    
    private var gridColumns: [SwiftUI.GridItem] {
        Array(repeating: SwiftUI.GridItem(.flexible(), spacing: horizontalSpacing), count: columns)
    }
    
    // Calculate cell size based on screen width
    private var cellSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalSpacing = horizontalSpacing * CGFloat(columns - 1)
        let totalPadding = horizontalPadding * 2
        let availableWidth = screenWidth - totalPadding - totalHorizontalSpacing
        return availableWidth / CGFloat(columns)
    }
    
    // MARK: - Data Management
    
    enum GridCellItem: Identifiable {
        case app(BookmarkedApp)
        case folder(AppFolder)
        
        var id: String {
            switch self {
            case .app(let app): return app.id
            case .folder(let folder): return folder.id
            }
        }
    }
    
    private var allItems: [GridCellItem] {
        var items: [GridCellItem] = []
        
        // Add apps not in folders
        let unfolderedApps = apps.filter { $0.folderId == nil }
        items.append(contentsOf: unfolderedApps.map { .app($0) })
        
        // Add folders
        items.append(contentsOf: folders.map { .folder($0) })
        
        // Sort by position
        items.sort { lhs, rhs in
            let lhsPosition: Int
            let rhsPosition: Int
            
            switch lhs {
            case .app(let app): lhsPosition = app.position
            case .folder(let folder): lhsPosition = folder.position
            }
            
            switch rhs {
            case .app(let app): rhsPosition = app.position
            case .folder(let folder): rhsPosition = folder.position
            }
            
            return lhsPosition < rhsPosition
        }
        
        return items
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: verticalSpacing) {
                ForEach(Array(allItems.enumerated()), id: \.element.id) { index, item in
                    cellView(for: item, at: index)
                }
                
                // Add empty cells to fill the grid if needed
                ForEach(allItems.count..<calculateTotalCells(), id: \.self) { index in
                    emptyCellView(at: index)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode.isEditing {
                        editMode.exitEditMode()
                    }
                }
        )
        .alert("Delete Folder?", isPresented: $showDeleteFolderAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.deleteFolderWithApps(folder)
                    }
                }
            }
        } message: {
            Text("This will also delete all apps inside this folder.")
        }
    }
    
    // MARK: - Cell Views
    
    @ViewBuilder
    private func cellView(for item: GridCellItem, at index: Int) -> some View {
        ZStack {
            cellBackground(at: index)
            cellContent(for: item, at: index)
        }
        .frame(width: cellSize, height: cellSize + 28)
        .customDraggable(item, editMode: editMode, index: index)
        .onDrop(of: [.text], isTargeted: dragTargetBinding(for: index)) { providers in
            handleDrop(at: index, providers: providers)
        }
    }
    
    @ViewBuilder
    private func cellBackground(at index: Int) -> some View {
        if editMode.folderCreationTargetIndex == index && editMode.isDragging {
            // Folder creation preview
            folderCreationPreview
        } else if editMode.folderAdditionTargetIndex == index && editMode.isDragging {
            // Folder addition preview
            folderAdditionPreview
        } else if editMode.highlightedCellIndex == index && editMode.isDragging && 
                  editMode.folderCreationTargetIndex != index && 
                  editMode.folderAdditionTargetIndex != index && 
                  index >= allItems.count {
            // Empty cell highlight
            EmptyCellHighlight(size: cellSize)
                .frame(width: cellSize, height: cellSize + 28)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: editMode.highlightedCellIndex)
        }
    }
    
    @ViewBuilder
    private var folderCreationPreview: some View {
        ZStack {
            FolderCreationPreview(size: cellSize)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode.folderCreationTargetIndex)
            
            if editMode.folderCreationProgress > 0 {
                FolderCreationProgressRing(
                    progress: editMode.folderCreationProgress,
                    size: cellSize
                )
            }
        }
    }
    
    @ViewBuilder
    private var folderAdditionPreview: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: cellSize * 0.3,
                        endRadius: cellSize * 0.6
                    )
                )
                .frame(width: cellSize * 1.2, height: cellSize * 1.2)
            
            if editMode.folderCreationProgress > 0 {
                FolderCreationProgressRing(
                    progress: editMode.folderCreationProgress,
                    size: cellSize
                )
            }
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode.folderAdditionTargetIndex)
    }
    
    @ViewBuilder
    private func cellContent(for item: GridCellItem, at index: Int) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                size: 74,
                editMode: editMode,
                onTap: { onAppTap(app) },
                onDelete: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.deleteApp(app)
                    }
                }
            )
            .opacity(editMode.isDraggingItem(with: app.id) ? 0.3 : 1.0)
            .scaleEffect(editMode.isCreatingFolder && editMode.folderCreationTargetIndex == index ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode.isCreatingFolder)
            
        case .folder(let folder):
            FolderIconView(
                folder: folder,
                apps: viewModel.appsInFolder(folder.id),
                size: 74,
                editMode: editMode,
                onTap: { onFolderTap(folder) },
                onDelete: {
                    folderToDelete = folder
                    showDeleteFolderAlert = true
                }
            )
            .opacity(editMode.isDraggingItem(with: folder.id) ? 0.3 : 1.0)
        }
    }
    
    @ViewBuilder
    private func emptyCellView(at index: Int) -> some View {
        ZStack {
            if editMode.highlightedCellIndex == index && editMode.isDragging {
                EmptyCellHighlight(size: cellSize)
                    .frame(width: cellSize, height: cellSize + 28)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.2), value: editMode.highlightedCellIndex)
            }
            
            Color.clear
                .frame(width: cellSize, height: cellSize + 28)
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode.isEditing {
                        editMode.exitEditMode()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    if !editMode.isEditing {
                        editMode.enterEditMode()
                    }
                }
        }
        .onDrop(of: [.text], isTargeted: Binding(
            get: { editMode.highlightedCellIndex == index },
            set: { isTargeted in
                if isTargeted && editMode.isDragging {
                    editMode.updateDragPosition(at: index, dropType: .overEmpty)
                } else if !isTargeted && editMode.highlightedCellIndex == index {
                    editMode.updateDragPosition(at: nil, dropType: .overEmpty)
                }
            }
        )) { providers in
            handleDrop(at: index, providers: providers)
        }
    }
    
    private func dragTargetBinding(for index: Int) -> Binding<Bool> {
        Binding(
            get: { 
                editMode.highlightedCellIndex == index || 
                editMode.folderCreationTargetIndex == index ||
                editMode.folderAdditionTargetIndex == index
            },
            set: { isTargeted in
                if isTargeted && editMode.isDragging {
                    let dropType: AppEditMode.DropType = {
                        guard index < allItems.count else { return .overEmpty }
                        switch allItems[index] {
                        case .app: return .overApp
                        case .folder: return .overFolder
                        }
                    }()
                    editMode.updateDragPosition(at: index, dropType: dropType)
                } else if !isTargeted {
                    editMode.updateDragPosition(at: nil, dropType: .overEmpty)
                }
            }
        )
    }
    
    private func calculateTotalCells() -> Int {
        // Calculate minimum cells needed for a clean grid
        let itemCount = allItems.count
        let rows = (itemCount + columns - 1) / columns
        return max(rows * columns, columns * 5) // At least 5 rows
    }
    
    // MARK: - Drag & Drop
    
    private func handleDrop(at index: Int, providers: [NSItemProvider]) -> Bool {
        guard editMode.isDragging,
              let draggedItem = editMode.draggedItem else { return false }
        
        // Store folder creation/addition state before clearing it
        let shouldCreateFolder = editMode.isCreatingFolder && editMode.folderCreationTargetIndex == index
        let shouldAddToFolder = editMode.isAddingToFolder && editMode.folderAdditionTargetIndex == index
        
        print("📱 AppsGridView: handleDrop - index: \(index)")
        print("📱   isCreatingFolder: \(editMode.isCreatingFolder), folderCreationTargetIndex: \(String(describing: editMode.folderCreationTargetIndex))")
        print("📱   isAddingToFolder: \(editMode.isAddingToFolder), folderAdditionTargetIndex: \(String(describing: editMode.folderAdditionTargetIndex))")
        print("📱   shouldCreateFolder: \(shouldCreateFolder), shouldAddToFolder: \(shouldAddToFolder)")
        
        // Clear drag state
        editMode.endDragging()
        
        // Handle different drop scenarios
        if shouldAddToFolder {
            // Add app to existing folder
            if let targetItem = allItems[safe: index] {
                print("📱 AppsGridView: Adding app to folder at index \(index)")
                Task {
                    await addToFolder(draggedItem: draggedItem, targetItem: targetItem)
                }
            } else {
                print("❌ AppsGridView: No target folder found at index \(index)")
            }
        } else if shouldCreateFolder {
            // Create new folder
            if let targetItem = allItems[safe: index] {
                print("📱 AppsGridView: Creating folder with target item at index \(index)")
                Task {
                    await createFolder(draggedItem: draggedItem, targetItem: targetItem)
                }
            } else {
                print("❌ AppsGridView: No target item found at index \(index)")
            }
        } else {
            // Regular reorder
            print("📱 AppsGridView: Regular reorder from \(draggedItem.sourceIndex) to \(index)")
            Task {
                await reorderItems(from: draggedItem.sourceIndex, to: index)
            }
        }
        
        return true
    }
    
    private func createFolder(draggedItem: AppEditMode.DraggedItem, targetItem: GridCellItem) async {
        guard draggedItem.isApp,
              case .app(let targetApp) = targetItem,
              let draggedApp = apps.first(where: { $0.id == draggedItem.id }) else {
            print("❌ AppsGridView: createFolder - Invalid items for folder creation")
            return
        }
        
        print("📱 AppsGridView: Creating folder from \(draggedApp.name) + \(targetApp.name)")
        
        // Create folder with suggested name
        let folderName = suggestFolderName(for: [draggedApp, targetApp])
        let folderColor = "#6366F1" // Default iOS blue
        
        print("📱 AppsGridView: Suggested folder name: \(folderName)")
        
        // Use the atomic method that handles everything properly
        let folder = await viewModel.createFolderAndReorganizeSimple(
            folderName: folderName,
            folderColor: folderColor,
            draggedApp: draggedApp,
            targetApp: targetApp
        )
        
        if let folder = folder {
            print("✅ AppsGridView: Successfully created folder: \(folder.name)")
        } else {
            print("❌ AppsGridView: Failed to create folder")
        }
    }
    
    private func suggestFolderName(for apps: [BookmarkedApp]) -> String {
        let appNames = apps.map { $0.name.lowercased() }
        
        if appNames.contains(where: { $0.contains("wallet") || $0.contains("metamask") }) {
            return "Wallets"
        } else if appNames.contains(where: { $0.contains("swap") || $0.contains("uniswap") }) {
            return "DeFi"
        } else if appNames.contains(where: { $0.contains("nft") || $0.contains("opensea") }) {
            return "NFTs"
        } else {
            return "Folder"
        }
    }
    
    private func addToFolder(draggedItem: AppEditMode.DraggedItem, targetItem: GridCellItem) async {
        guard draggedItem.isApp,
              case .folder(let targetFolder) = targetItem,
              let draggedApp = apps.first(where: { $0.id == draggedItem.id }) else {
            print("❌ AppsGridView: addToFolder - Invalid items for folder addition")
            return
        }
        
        print("📱 AppsGridView: Adding \(draggedApp.name) to folder \(targetFolder.name)")
        
        // Move app to folder
        let success = await viewModel.moveAppToFolder(draggedApp, folderId: targetFolder.id)
        
        if success {
            print("✅ AppsGridView: Successfully added app to folder")
        } else {
            print("❌ AppsGridView: Failed to add app to folder")
        }
    }
    
    private func reorderItems(from sourceIndex: Int, to targetIndex: Int) async {
        guard sourceIndex != targetIndex else { return }
        
        var items = allItems
        guard sourceIndex < items.count else { return }
        
        let movedItem = items.remove(at: sourceIndex)
        let insertIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        
        if insertIndex <= items.count {
            items.insert(movedItem, at: insertIndex)
            
            // Update positions
            var appIds: [String] = []
            var folderIds: [String] = []
            
            for (index, item) in items.enumerated() {
                switch item {
                case .app(let app):
                    appIds.append(app.id)
                case .folder(let folder):
                    folderIds.append(folder.id)
                }
            }
            
            // Update backend
            if !appIds.isEmpty {
                await viewModel.reorderApps(appIds)
            }
            if !folderIds.isEmpty {
                await viewModel.reorderFolders(folderIds)
            }
        }
    }
}

// MARK: - Draggable Modifier

extension View {
    func customDraggable<T>(_ item: T, editMode: AppEditMode, index: Int) -> some View where T: Any {
        self.onDrag {
            guard editMode.isEditing else {
                return NSItemProvider()
            }
            
            let itemId: String
            let isApp: Bool
            
            if let gridItem = item as? AppsGridView.GridCellItem {
                switch gridItem {
                case .app(let app):
                    itemId = app.id
                    isApp = true
                case .folder(let folder):
                    itemId = folder.id
                    isApp = false
                }
                
                editMode.startDragging(item: AppEditMode.DraggedItem(
                    id: itemId,
                    isApp: isApp,
                    sourceIndex: index
                ))
            }
            
            return NSItemProvider(object: NSString(string: "drag"))
        }
    }
}

// MARK: - Safe Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
