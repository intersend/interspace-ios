import SwiftUI
import Combine

// MARK: - Springboard State Manager

/// Centralized state management for iOS-native springboard behavior
@MainActor
final class SpringboardStateManager: ObservableObject {
    
    // MARK: - State Types
    
    enum Mode: Equatable {
        case normal
        case editing
        case dragging(itemId: String, snapshot: UIImage?)
    }
    
    enum DragState: Equatable {
        case inactive
        case pressing(location: CGPoint)
        case dragging(translation: CGSize, location: CGPoint)
    }
    
    struct IconState: Equatable {
        let id: String
        var scale: CGFloat = 1.0
        var opacity: Double = 1.0
        var rotation: Double = 0
        var offset: CGSize = .zero
        var isWiggling: Bool = false
        var isDragging: Bool = false
        var isDropTarget: Bool = false
    }
    
    // MARK: - Published Properties
    
    @Published var mode: Mode = .normal
    @Published var dragState: DragState = .inactive
    @Published var iconStates: [String: IconState] = [:]
    @Published var dropTargetId: String?
    @Published var folderCreationProgress: CGFloat = 0
    @Published var pendingFolderItems: (String, String)?
    
    // MARK: - Private Properties
    
    private var longPressTimer: Timer?
    private var folderCreationTimer: Timer?
    private var autoScrollTimer: Timer?
    private var hapticPrepared = false
    
    // Animation completion tracking
    private var animationCompletions: [UUID: () -> Void] = [:]
    
    // MARK: - Computed Properties
    
    var isEditing: Bool {
        switch mode {
        case .normal:
            return false
        case .editing, .dragging:
            return true
        }
    }
    
    var isDragging: Bool {
        if case .dragging = mode {
            return true
        }
        return false
    }
    
    // MARK: - Initialization
    
    init() {
        // Prepare haptic engine
        prepareHaptics()
    }
    
    // MARK: - Mode Management
    
    func enterEditMode() {
        guard mode == .normal else { return }
        
        // Clean state first
        cleanupDragStates()
        
        mode = .editing
        
        // Start wiggle for all icons
        for id in iconStates.keys {
            iconStates[id]?.isWiggling = true
        }
        
        HapticManager.impact(.medium)
    }
    
    func exitEditMode() {
        guard isEditing else { return }
        
        // Stop all animations first
        for id in iconStates.keys {
            iconStates[id]?.isWiggling = false
        }
        
        // Clean up all states
        cleanupDragStates()
        mode = .normal
        
        HapticManager.impact(.light)
    }
    
    // MARK: - Icon State Management
    
    func registerIcon(id: String) {
        if iconStates[id] == nil {
            iconStates[id] = IconState(id: id)
        }
    }
    
    func unregisterIcon(id: String) {
        iconStates[id] = nil
    }
    
    func resetIconState(id: String) {
        iconStates[id] = IconState(id: id)
    }
    
    // MARK: - Long Press Handling
    
    func handleLongPressBegan(at location: CGPoint, itemId: String) {
        guard mode == .normal else { return }
        
        dragState = .pressing(location: location)
        
        // Prepare haptic
        if !hapticPrepared {
            prepareHaptics()
        }
        
        // Start timer for edit mode
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.handleLongPressCompleted(itemId: itemId)
        }
    }
    
    func handleLongPressChanged(at location: CGPoint) {
        if case .pressing(let startLocation) = dragState {
            let distance = hypot(location.x - startLocation.x, location.y - startLocation.y)
            if distance > 10 { // Movement threshold
                cancelLongPress()
            }
        }
    }
    
    func handleLongPressEnded() {
        cancelLongPress()
    }
    
    private func handleLongPressCompleted(itemId: String) {
        enterEditMode()
        
        // Immediately prepare for drag
        iconStates[itemId]?.scale = 1.05
        HapticManager.impact(.medium)
    }
    
    private func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        if case .pressing = dragState {
            dragState = .inactive
        }
    }
    
    // MARK: - Drag Handling
    
    func startDragging(itemId: String, snapshot: UIImage?) {
        guard isEditing else { return }
        
        mode = .dragging(itemId: itemId, snapshot: snapshot)
        
        // Update icon state
        iconStates[itemId]?.isDragging = true
        iconStates[itemId]?.scale = 1.15
        iconStates[itemId]?.opacity = 0.01 // Hide original
        iconStates[itemId]?.isWiggling = false
        
        HapticManager.impact(.medium)
    }
    
    func handleDragBegan(itemId: String, at location: CGPoint, snapshot: UIImage?) {
        startDragging(itemId: itemId, snapshot: snapshot)
        dragState = .dragging(translation: .zero, location: location)
    }
    
    func handleDragChanged(translation: CGSize, location: CGPoint) {
        guard case .dragging = mode else { return }
        
        dragState = .dragging(translation: translation, location: location)
        
        // Check for auto-scroll
        checkAutoScroll(at: location)
        
        // Check for drop targets
        checkDropTarget(at: location)
    }
    
    func endDragging() {
        guard case let .dragging(itemId, _) = mode else { return }
        
        // Reset states with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            iconStates[itemId]?.isDragging = false
            iconStates[itemId]?.scale = 1.0
            iconStates[itemId]?.opacity = 1.0
            iconStates[itemId]?.isWiggling = true
            
            // Reset drop target
            if let targetId = dropTargetId {
                iconStates[targetId]?.isDropTarget = false
            }
            dropTargetId = nil
        }
        
        // Clean up
        mode = .editing
        dragState = .inactive
        cancelAutoScroll()
        cancelFolderCreation()
        
        HapticManager.impact(.light)
    }
    
    func handleDragEnded() {
        endDragging()
    }
    
    // MARK: - Drop Target Detection
    
    private func checkDropTarget(at location: CGPoint) {
        // This will be called by the view to update drop targets
        // The view has access to the actual frame information
    }
    
    func setDropTarget(_ targetId: String?) {
        updateDropTarget(targetId)
    }
    
    func updateDropTarget(_ targetId: String?) {
        // Clear previous target
        if let oldTarget = dropTargetId, oldTarget != targetId {
            iconStates[oldTarget]?.isDropTarget = false
        }
        
        // Set new target
        dropTargetId = targetId
        if let targetId = targetId {
            iconStates[targetId]?.isDropTarget = true
            
            // Check for folder creation
            if case let .dragging(draggedId, _) = mode {
                checkFolderCreation(draggedId: draggedId, targetId: targetId)
            }
            
            HapticManager.selection()
        } else {
            cancelFolderCreation()
        }
    }
    
    // MARK: - Folder Creation
    
    func checkFolderCreation(draggedId: String, targetId: String) {
        // Start folder creation timer
        pendingFolderItems = (draggedId, targetId)
        folderCreationProgress = 0
        
        folderCreationTimer?.invalidate()
        folderCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.folderCreationProgress += 0.1
            
            if self.folderCreationProgress >= 1.0 {
                self.folderCreationTimer?.invalidate()
                HapticManager.notification(.success)
            }
        }
    }
    
    private func cancelFolderCreation() {
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil
        folderCreationProgress = 0
        pendingFolderItems = nil
    }
    
    // MARK: - Auto Scrolling
    
    private func checkAutoScroll(at location: CGPoint) {
        // This will be implemented by the view that has access to scroll view
    }
    
    private func cancelAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    // MARK: - Drop Handling
    
    private func performDrop(draggedId: String, targetId: String) {
        // This will trigger the actual data model changes
        // The view model will handle the actual app/folder operations
    }
    
    // MARK: - State Cleanup
    
    private func cleanupDragStates() {
        // Reset all icon states
        for id in iconStates.keys {
            iconStates[id]?.scale = 1.0
            iconStates[id]?.opacity = 1.0
            iconStates[id]?.rotation = 0
            iconStates[id]?.offset = .zero
            iconStates[id]?.isDragging = false
            iconStates[id]?.isDropTarget = false
        }
        
        // Clear drag state
        dragState = .inactive
        dropTargetId = nil
        
        // Cancel timers
        cancelLongPress()
        cancelAutoScroll()
        cancelFolderCreation()
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        // Prepare haptic engine for better responsiveness
        hapticPrepared = true
    }
    
    // MARK: - Animation Helpers
    
    func animate<Result>(
        _ animation: Animation,
        _ body: () throws -> Result,
        completion: (() -> Void)? = nil
    ) rethrows -> Result {
        let uuid = UUID()
        
        if let completion = completion {
            animationCompletions[uuid] = completion
        }
        
        return try withAnimation(animation) {
            let result = try body()
            
            // Schedule completion
            if completion != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.animationCompletions[uuid]?()
                    self?.animationCompletions[uuid] = nil
                }
            }
            
            return result
        }
    }
}

// MARK: - View Extensions

extension View {
    func springboardIcon(id: String, stateManager: SpringboardStateManager) -> some View {
        self
            .scaleEffect(stateManager.iconStates[id]?.scale ?? 1.0)
            .opacity(stateManager.iconStates[id]?.opacity ?? 1.0)
            .rotationEffect(.degrees(stateManager.iconStates[id]?.rotation ?? 0))
            .offset(stateManager.iconStates[id]?.offset ?? .zero)
            .onAppear {
                stateManager.registerIcon(id: id)
            }
            .onDisappear {
                stateManager.unregisterIcon(id: id)
            }
    }
}