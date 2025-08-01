import SwiftUI
import Combine

// MARK: - App Edit Mode
// Manages the edit state for the apps grid

@MainActor
class AppEditMode: ObservableObject {
    @Published var isEditing = false
    @Published var isDragging = false
    @Published var draggedItem: DraggedItem?
    @Published var highlightedCellIndex: Int?
    @Published var folderCreationTargetIndex: Int?
    @Published var isCreatingFolder = false
    @Published var folderAdditionTargetIndex: Int?
    @Published var isAddingToFolder = false
    
    // Animation state
    @Published var wiggleAnimation = false
    @Published var folderCreationProgress: Double = 0
    @Published var morphingAppIds: Set<String> = []
    
    // Folder creation timer
    private var folderCreationTimer: Timer?
    private let folderCreationDelay: TimeInterval = 0.5
    
    // Drag state
    struct DraggedItem {
        let id: String
        let isApp: Bool
        let sourceIndex: Int
    }
    
    // Drop type
    enum DropType {
        case overApp
        case overFolder
        case overEmpty
    }
    
    // MARK: - Edit Mode Control
    
    func enterEditMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditing = true
            wiggleAnimation = true
        }
        
        // Haptic feedback
        HapticManager.impact(.medium)
    }
    
    func exitEditMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditing = false
            wiggleAnimation = false
            isDragging = false
            draggedItem = nil
            highlightedCellIndex = nil
        }
        
        // Haptic feedback
        HapticManager.impact(.light)
    }
    
    // MARK: - Drag State Management
    
    func startDragging(item: DraggedItem) {
        isDragging = true
        draggedItem = item
        
        // Haptic feedback for lift
        HapticManager.impact(.medium)
    }
    
    func updateDragPosition(at cellIndex: Int?, dropType: DropType) {
        // Don't clear folder creation/addition state if we're about to drop
        if cellIndex == nil && (isCreatingFolder || isAddingToFolder) && 
           (folderCreationTargetIndex != nil || folderAdditionTargetIndex != nil) {
            print("🎯 AppEditMode: Preserving drop state")
            return
        }
        
        if highlightedCellIndex != cellIndex {
            highlightedCellIndex = cellIndex
            
            // Cancel existing timer
            folderCreationTimer?.invalidate()
            folderCreationProgress = 0
            
            // Handle different drop types
            if let cellIndex = cellIndex,
               let draggedItem = draggedItem,
               draggedItem.isApp && cellIndex != draggedItem.sourceIndex {
                
                switch dropType {
                case .overApp:
                    print("🎯 AppEditMode: Hovering over app at index \(cellIndex), starting folder creation timer")
                    folderCreationTargetIndex = cellIndex
                    folderAdditionTargetIndex = nil
                    startFolderCreationTimer()
                    
                case .overFolder:
                    print("🎯 AppEditMode: Hovering over folder at index \(cellIndex), starting folder addition timer")
                    folderAdditionTargetIndex = cellIndex
                    folderCreationTargetIndex = nil
                    startFolderAdditionTimer()
                    
                case .overEmpty:
                    folderCreationTargetIndex = nil
                    folderAdditionTargetIndex = nil
                }
            } else {
                folderCreationTargetIndex = nil
                folderAdditionTargetIndex = nil
            }
            
            // Light haptic when entering new cell
            if cellIndex != nil {
                HapticManager.impact(.light)
            }
        }
    }
    
    private func startFolderCreationTimer() {
        folderCreationTimer?.invalidate()
        folderCreationProgress = 0
        
        print("⏱️ AppEditMode: Starting folder creation timer")
        
        folderCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            withAnimation(.linear(duration: 0.02)) {
                self.folderCreationProgress = min(1.0, self.folderCreationProgress + (0.02 / self.folderCreationDelay))
            }
            
            if self.folderCreationProgress >= 1.0 {
                self.folderCreationTimer?.invalidate()
                self.isCreatingFolder = true
                print("✅ AppEditMode: Folder creation timer completed, isCreatingFolder = true")
                HapticManager.notification(.success)
            }
        }
    }
    
    private func startFolderAdditionTimer() {
        folderCreationTimer?.invalidate()
        folderCreationProgress = 0
        
        print("⏱️ AppEditMode: Starting folder addition timer")
        
        folderCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            withAnimation(.linear(duration: 0.02)) {
                self.folderCreationProgress = min(1.0, self.folderCreationProgress + (0.02 / self.folderCreationDelay))
            }
            
            if self.folderCreationProgress >= 1.0 {
                self.folderCreationTimer?.invalidate()
                self.isAddingToFolder = true
                print("✅ AppEditMode: Folder addition timer completed, isAddingToFolder = true")
                HapticManager.notification(.success)
            }
        }
    }
    
    func endDragging() {
        isDragging = false
        draggedItem = nil
        highlightedCellIndex = nil
        folderCreationTargetIndex = nil
        folderAdditionTargetIndex = nil
        folderCreationTimer?.invalidate()
        folderCreationProgress = 0
        isCreatingFolder = false
        isAddingToFolder = false
        
        // Haptic feedback for drop
        HapticManager.impact(.light)
    }
    
    
    // MARK: - Folder Creation
    
    func startFolderCreationAnimation(draggedId: String, targetId: String) {
        // Store the morphing app IDs for animation
        morphingAppIds.insert(draggedId)
        morphingAppIds.insert(targetId)
    }
    
    func startItemsShiftAnimation() {
        // Trigger any necessary animations for shifting items
        // This is a placeholder for now
    }
    
    func endFolderCreationAnimation() {
        // End folder creation animation state
        morphingAppIds.removeAll()
    }
    
    func endItemsShiftAnimation() {
        // Reset any item shift animations
        // This is a placeholder for now
    }
    
    func resetFolderCreation() {
        isCreatingFolder = false
        folderCreationTargetIndex = nil
        morphingAppIds.removeAll()
        folderCreationProgress = 0
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil
    }
    
    // MARK: - Helpers
    
    func shouldShowDeleteBadge(for itemId: String) -> Bool {
        return isEditing && !isDragging
    }
    
    func shouldWiggle(for itemId: String) -> Bool {
        return wiggleAnimation && draggedItem?.id != itemId
    }
    
    func isDraggingItem(with id: String) -> Bool {
        return draggedItem?.id == id
    }
}