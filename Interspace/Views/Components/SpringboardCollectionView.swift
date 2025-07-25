import SwiftUI
import UIKit

// MARK: - Springboard Collection View

struct SpringboardCollectionView: UIViewRepresentable {
    @Binding var apps: [BookmarkedApp]
    @Binding var folders: [AppFolder]
    let stateManager: SpringboardStateManager
    let viewModel: AppsViewModel
    let onAppTap: (BookmarkedApp) -> Void
    let onFolderTap: (AppFolder) -> Void
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = SpringboardFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        // Configure collection view
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.contentInsetAdjustmentBehavior = .never
        
        // Performance optimizations
        collectionView.isPrefetchingEnabled = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.decelerationRate = .fast
        
        // Register cells
        collectionView.register(SpringboardIconCell.self, forCellWithReuseIdentifier: "IconCell")
        
        // Set up data source and delegate
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.prefetchDataSource = context.coordinator
        
        // Set up gesture recognizers
        context.coordinator.setupGestures(for: collectionView)
        
        return collectionView
    }
    
    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        // Update data
        context.coordinator.apps = apps
        context.coordinator.folders = folders
        
        // Only reload if not dragging
        if !stateManager.isDragging {
            collectionView.reloadData()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Animation Coordinator
    
    class AnimationCoordinator {
        private var activeAnimations: Set<String> = []
        private let queue = DispatchQueue(label: "springboard.animations", attributes: .concurrent)
        
        func performAnimation(id: String, duration: TimeInterval, animations: @escaping () -> Void, completion: (() -> Void)? = nil) {
            queue.async(flags: .barrier) {
                self.activeAnimations.insert(id)
            }
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            CATransaction.setCompletionBlock {
                self.queue.async(flags: .barrier) {
                    self.activeAnimations.remove(id)
                }
                completion?()
            }
            
            animations()
            
            CATransaction.commit()
        }
        
        func isAnimating(_ id: String) -> Bool {
            queue.sync {
                activeAnimations.contains(id)
            }
        }
        
        func cancelAnimation(_ id: String) {
            queue.async(flags: .barrier) {
                self.activeAnimations.remove(id)
            }
        }
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UICollectionViewDataSourcePrefetching {
        var parent: SpringboardCollectionView?
        var apps: [BookmarkedApp] = []
        var folders: [AppFolder] = []
        
        // Animation coordinator
        let animationCoordinator = AnimationCoordinator()
        
        // Gesture recognizers
        var longPressGesture: UILongPressGestureRecognizer!
        var panGesture: UIPanGestureRecognizer!
        
        // Drag state
        var draggedIndexPath: IndexPath?
        var draggedView: UIView?
        var originalCenter: CGPoint?
        
        // Auto-scroll
        var autoScrollTimer: Timer?
        var autoScrollDirection: CGFloat = 0
        var dropTargetView: UIView?
        
        // Edge glow views
        var leftEdgeGlow: UIView?
        var rightEdgeGlow: UIView?
        
        init(_ parent: SpringboardCollectionView) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - Gesture Setup
        
        func setupGestures(for collectionView: UICollectionView) {
            // Long press for entering edit mode and initiating drag
            longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPressGesture.minimumPressDuration = 0.5
            longPressGesture.delegate = self
            collectionView.addGestureRecognizer(longPressGesture)
            
            // Pan for dragging
            panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.delegate = self
            collectionView.addGestureRecognizer(panGesture)
            
            // Require long press before pan
            panGesture.require(toFail: longPressGesture)
        }
        
        // MARK: - Gesture Handlers
        
        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView = gesture.view as? UICollectionView else { return }
            let location = gesture.location(in: collectionView)
            
            switch gesture.state {
            case .began:
                // Enter edit mode
                parent?.stateManager.enterEditMode()
                
                // Find the item at this location
                if let indexPath = collectionView.indexPathForItem(at: location),
                   let cell = collectionView.cellForItem(at: indexPath) as? SpringboardIconCell {
                    
                    // Start dragging
                    startDragging(cell: cell, at: indexPath, in: collectionView)
                    
                    // iOS-style haptic sequence for drag start
                    HapticManager.impact(.light)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        HapticManager.impact(.medium)
                    }
                }
                
            case .changed:
                // Update drag position
                if let draggedView = draggedView {
                    draggedView.center = location
                    
                    // Check for auto-scroll
                    checkAutoScroll(at: location, in: collectionView)
                    
                    // Check for drop targets
                    checkDropTarget(at: location, in: collectionView)
                }
                
            case .ended, .cancelled:
                // End dragging
                endDragging(in: collectionView)
                
            default:
                break
            }
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let parent = parent,
                  parent.stateManager.isDragging,
                  let collectionView = gesture.view as? UICollectionView,
                  let draggedView = draggedView else { return }
            
            let location = gesture.location(in: collectionView)
            let velocity = gesture.velocity(in: collectionView)
            
            switch gesture.state {
            case .changed:
                // Update position
                draggedView.center = location
                
                // iOS-style drag physics
                let horizontalVelocity = velocity.x
                let dampedRotation = atan(horizontalVelocity / 3000) * 0.5 // More subtle rotation
                let tiltScale = 1.0 + abs(dampedRotation) * 0.05 // Slight scale based on tilt
                
                // Apply smooth transform with explicit transaction
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.1)
                CATransaction.setCompletionBlock(nil)
                
                UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                    draggedView.transform = CGAffineTransform(rotationAngle: dampedRotation)
                        .scaledBy(x: 1.1 * tiltScale, y: 1.1 * tiltScale)
                }
                
                CATransaction.commit()
                
                // Dynamic shadow based on velocity
                let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                let shadowOffset = 10 + min(speed / 100, 5)
                draggedView.layer.shadowOffset = CGSize(width: 0, height: shadowOffset)
                
                // Check for auto-scroll
                checkAutoScroll(at: location, in: collectionView)
                
                // Check for drop targets
                checkDropTarget(at: location, in: collectionView)
                
            case .ended:
                // End dragging with velocity
                endDragging(in: collectionView, velocity: velocity)
                
            default:
                break
            }
        }
        
        // MARK: - Drag & Drop Methods
        
        private func startDragging(cell: SpringboardIconCell, at indexPath: IndexPath, in collectionView: UICollectionView) {
            draggedIndexPath = indexPath
            
            // Create snapshot with iOS-style rendering
            guard let snapshot = cell.snapshotView(afterScreenUpdates: true) else { return }
            
            // Position in collection view's coordinate space
            let cellFrame = cell.frame
            snapshot.center = CGPoint(x: cellFrame.midX, y: cellFrame.midY)
            
            // Configure initial appearance
            snapshot.alpha = 1.0
            snapshot.layer.masksToBounds = false
            snapshot.layer.shouldRasterize = true
            snapshot.layer.rasterizationScale = UIScreen.main.scale
            
            // Add to collection view
            collectionView.addSubview(snapshot)
            draggedView = snapshot
            originalCenter = snapshot.center
            
            // iOS-style shadow setup (invisible initially)
            snapshot.layer.shadowColor = UIColor.black.cgColor
            snapshot.layer.shadowOffset = CGSize(width: 0, height: 0)
            snapshot.layer.shadowRadius = 0
            snapshot.layer.shadowOpacity = 0
            snapshot.layer.shadowPath = UIBezierPath(roundedRect: snapshot.bounds, cornerRadius: 14).cgPath
            
            // Hide original cell with fade
            animationCoordinator.performAnimation(id: "hide-cell-\(indexPath.item)", duration: 0.15, animations: {
                UIView.animate(withDuration: 0.15) {
                    cell.alpha = 0.01
                }
            })
            
            // iOS-style lift animation sequence with explicit transaction
            animationCoordinator.performAnimation(id: "lift-\(indexPath.item)", duration: 0.3, animations: {
                UIView.animateKeyframes(withDuration: 0.3, delay: 0, options: .calculationModeCubic) {
                    // Phase 1: Initial lift (0-40%)
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.4) {
                        snapshot.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                        snapshot.layer.shadowOffset = CGSize(width: 0, height: 4)
                        snapshot.layer.shadowRadius = 8
                        snapshot.layer.shadowOpacity = 0.15
                    }
                    
                    // Phase 2: Overshoot (40-70%)
                    UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.3) {
                        snapshot.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
                        snapshot.layer.shadowOffset = CGSize(width: 0, height: 12)
                        snapshot.layer.shadowRadius = 16
                        snapshot.layer.shadowOpacity = 0.25
                    }
                    
                    // Phase 3: Settle (70-100%)
                    UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                        snapshot.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                        snapshot.layer.shadowOffset = CGSize(width: 0, height: 10)
                        snapshot.layer.shadowRadius = 14
                        snapshot.layer.shadowOpacity = 0.22
                    }
                }
            })
            
            // Subtle bounce haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticManager.impact(.light)
            }
            
            // Update state
            if let item = getItem(at: indexPath) {
                parent?.stateManager.startDragging(itemId: item.id, snapshot: nil)
            }
        }
        
        private func checkAutoScroll(at location: CGPoint, in collectionView: UICollectionView) {
            let edgeThreshold: CGFloat = 60
            let innerThreshold: CGFloat = 100
            let maxScrollSpeed: CGFloat = 12
            
            // Calculate distance from edges
            let leftDistance = location.x
            let rightDistance = collectionView.bounds.width - location.x
            
            // Progressive scroll speed based on distance from edge
            if leftDistance < innerThreshold {
                let progress = 1.0 - (max(0, leftDistance - edgeThreshold) / (innerThreshold - edgeThreshold))
                let speed = -maxScrollSpeed * progress * progress // Quadratic easing
                
                if autoScrollDirection != speed {
                    autoScrollDirection = speed
                    startAutoScroll(in: collectionView)
                    
                    // Visual feedback for edge proximity
                    if leftDistance < edgeThreshold {
                        showEdgeGlow(on: .left, in: collectionView)
                    }
                }
            } else if rightDistance < innerThreshold {
                let progress = 1.0 - (max(0, rightDistance - edgeThreshold) / (innerThreshold - edgeThreshold))
                let speed = maxScrollSpeed * progress * progress
                
                if autoScrollDirection != speed {
                    autoScrollDirection = speed
                    startAutoScroll(in: collectionView)
                    
                    // Visual feedback for edge proximity
                    if rightDistance < edgeThreshold {
                        showEdgeGlow(on: .right, in: collectionView)
                    }
                }
            } else {
                // Stop scrolling
                stopAutoScroll()
                hideEdgeGlow()
            }
        }
        
        private func showEdgeGlow(on edge: Edge, in collectionView: UICollectionView) {
            // Remove any existing glow on this edge
            switch edge {
            case .left:
                leftEdgeGlow?.removeFromSuperview()
                leftEdgeGlow = createEdgeGlow(for: .left, in: collectionView)
            case .right:
                rightEdgeGlow?.removeFromSuperview()
                rightEdgeGlow = createEdgeGlow(for: .right, in: collectionView)
            }
        }
        
        private func createEdgeGlow(for edge: Edge, in collectionView: UICollectionView) -> UIView {
            let glowView = UIView()
            glowView.isUserInteractionEnabled = false
            glowView.layer.zPosition = 100 // Above content
            
            // iOS-native edge indicator size
            let glowWidth: CGFloat = 80
            
            // Create multi-layer gradient for depth
            let gradient = CAGradientLayer()
            gradient.frame = CGRect(x: 0, y: 0, width: glowWidth, height: collectionView.bounds.height)
            
            // iOS 18 style colors with subtle blue tint
            let baseColor = UIColor.systemBlue
            let intensity: CGFloat = 0.5
            
            switch edge {
            case .left:
                gradient.colors = [
                    baseColor.withAlphaComponent(intensity * 0.4).cgColor,
                    baseColor.withAlphaComponent(intensity * 0.25).cgColor,
                    baseColor.withAlphaComponent(intensity * 0.1).cgColor,
                    UIColor.clear.cgColor
                ]
                gradient.locations = [0, 0.3, 0.6, 1]
                gradient.startPoint = CGPoint(x: 0, y: 0.5)
                gradient.endPoint = CGPoint(x: 1, y: 0.5)
                glowView.frame = CGRect(x: 0, y: 0, width: glowWidth, height: collectionView.bounds.height)
                
            case .right:
                gradient.colors = [
                    UIColor.clear.cgColor,
                    baseColor.withAlphaComponent(intensity * 0.1).cgColor,
                    baseColor.withAlphaComponent(intensity * 0.25).cgColor,
                    baseColor.withAlphaComponent(intensity * 0.4).cgColor
                ]
                gradient.locations = [0, 0.4, 0.7, 1]
                gradient.startPoint = CGPoint(x: 0, y: 0.5)
                gradient.endPoint = CGPoint(x: 1, y: 0.5)
                glowView.frame = CGRect(x: collectionView.bounds.width - glowWidth, y: 0, width: glowWidth, height: collectionView.bounds.height)
            }
            
            glowView.layer.addSublayer(gradient)
            
            // Add blur effect layer for more depth
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = glowView.bounds
            blurView.alpha = 0.3
            glowView.insertSubview(blurView, at: 0)
            
            glowView.alpha = 0
            collectionView.addSubview(glowView)
            
            // Animate in with spring
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                glowView.alpha = 1.0
            }
            
            // Create shimmer animation
            let shimmerAnimation = CABasicAnimation(keyPath: "opacity")
            shimmerAnimation.fromValue = 0.7
            shimmerAnimation.toValue = 1.0
            shimmerAnimation.duration = 1.2
            shimmerAnimation.autoreverses = true
            shimmerAnimation.repeatCount = .infinity
            shimmerAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.42, 0, 0.58, 1.0)
            gradient.add(shimmerAnimation, forKey: "shimmer")
            
            // Add subtle position animation for movement effect
            let moveAnimation = CABasicAnimation(keyPath: "position.x")
            moveAnimation.byValue = edge == .left ? 5 : -5
            moveAnimation.duration = 2.0
            moveAnimation.autoreverses = true
            moveAnimation.repeatCount = .infinity
            moveAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            gradient.add(moveAnimation, forKey: "move")
            
            return glowView
        }
        
        private func hideEdgeGlow() {
            UIView.animate(withDuration: 0.3) {
                self.leftEdgeGlow?.alpha = 0
                self.rightEdgeGlow?.alpha = 0
            } completion: { _ in
                self.leftEdgeGlow?.removeFromSuperview()
                self.rightEdgeGlow?.removeFromSuperview()
                self.leftEdgeGlow = nil
                self.rightEdgeGlow = nil
            }
        }
        
        private func startAutoScroll(in collectionView: UICollectionView) {
            guard autoScrollTimer == nil else { return }
            
            // For page-based scrolling like springboard
            let pageWidth = collectionView.bounds.width
            let currentPage = round(collectionView.contentOffset.x / pageWidth)
            
            autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                var offset = collectionView.contentOffset
                let proposedOffset = offset.x + self.autoScrollDirection
                
                // Check if we should transition to next/previous page
                let proposedPage = round(proposedOffset / pageWidth)
                let maxPage = floor(collectionView.contentSize.width / pageWidth)
                
                if self.autoScrollDirection > 0 && proposedPage > currentPage {
                    // Moving to next page
                    let targetOffset = min(proposedPage * pageWidth, collectionView.contentSize.width - pageWidth)
                    
                    // Smooth page transition
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                        collectionView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: false)
                    } completion: { _ in
                        self.stopAutoScroll()
                        // Resume if still at edge
                        if let draggedView = self.draggedView {
                            let location = draggedView.center
                            self.checkAutoScroll(at: location, in: collectionView)
                        }
                    }
                    
                    self.autoScrollTimer?.invalidate()
                    self.autoScrollTimer = nil
                    
                } else if self.autoScrollDirection < 0 && proposedPage < currentPage {
                    // Moving to previous page
                    let targetOffset = max(proposedPage * pageWidth, 0)
                    
                    // Smooth page transition
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                        collectionView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: false)
                    } completion: { _ in
                        self.stopAutoScroll()
                        // Resume if still at edge
                        if let draggedView = self.draggedView {
                            let location = draggedView.center
                            self.checkAutoScroll(at: location, in: collectionView)
                        }
                    }
                    
                    self.autoScrollTimer?.invalidate()
                    self.autoScrollTimer = nil
                    
                } else {
                    // Continue scrolling within page boundaries
                    offset.x = proposedOffset
                    
                    // Clamp to bounds
                    let maxOffset = collectionView.contentSize.width - collectionView.bounds.width
                    offset.x = max(0, min(offset.x, maxOffset))
                    
                    collectionView.setContentOffset(offset, animated: false)
                }
            }
        }
        
        private func stopAutoScroll() {
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
            autoScrollDirection = 0
        }
        
        enum Edge {
            case left
            case right
        }
        
        private func checkDropTarget(at location: CGPoint, in collectionView: UICollectionView) {
            guard let draggedIndexPath = draggedIndexPath else { return }
            
            // Find target cell
            if let targetIndexPath = collectionView.indexPathForItem(at: location),
               targetIndexPath != draggedIndexPath,
               let targetCell = collectionView.cellForItem(at: targetIndexPath) as? SpringboardIconCell {
                
                if let targetItem = getItem(at: targetIndexPath),
                   let draggedItem = getItem(at: draggedIndexPath) {
                    
                    // Check if we should create a folder
                    if shouldCreateFolder(draggedItem, targetItem) {
                        // Update drop target
                        if dropTargetView?.tag != targetIndexPath.item {
                            clearDropTargetHighlight()
                            parent?.stateManager.setDropTarget(targetItem.id)
                            showFolderCreationPreview(on: targetCell, at: targetIndexPath)
                        }
                    } else {
                        // Clear any folder preview
                        clearDropTargetHighlight()
                        parent?.stateManager.setDropTarget(nil)
                        
                        // iOS-style reordering with smooth animation
                        let impactLocation = collectionView.convert(location, to: targetCell)
                        let isLeftHalf = impactLocation.x < targetCell.bounds.midX
                        
                        // Only reorder if we've crossed the midpoint
                        let shouldReorder = isLeftHalf ? targetIndexPath.item < draggedIndexPath.item : targetIndexPath.item > draggedIndexPath.item
                        
                        if shouldReorder {
                            // Animate cell movements with iOS timing
                            collectionView.performBatchUpdates({
                                collectionView.moveItem(at: draggedIndexPath, to: targetIndexPath)
                                self.draggedIndexPath = targetIndexPath
                            }, completion: nil)
                            
                            // Light haptic for reorder
                            HapticManager.impact(.light)
                        }
                    }
                }
            } else {
                // Clear highlights when not over any cell
                clearDropTargetHighlight()
                parent?.stateManager.setDropTarget(nil)
            }
        }
        
        private func showFolderCreationPreview(on cell: SpringboardIconCell, at indexPath: IndexPath) {
            // Remove any existing preview
            dropTargetView?.removeFromSuperview()
            
            // Create iOS-style folder preview container
            let previewContainer = UIView(frame: cell.bounds)
            previewContainer.tag = indexPath.item
            previewContainer.backgroundColor = .clear
            
            // Create morphing shape layer
            let morphLayer = CAShapeLayer()
            morphLayer.frame = previewContainer.bounds
            morphLayer.fillColor = UIColor.white.withAlphaComponent(0.08).cgColor
            morphLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
            morphLayer.lineWidth = 1.5
            
            // Initial circle path (app icon shape)
            let initialPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 60), 
                                          cornerRadius: 13.5)
            morphLayer.path = initialPath.cgPath
            
            previewContainer.layer.addSublayer(morphLayer)
            
            // Create folder grid preview (4 mini icons)
            let gridContainer = UIView()
            gridContainer.frame = CGRect(x: 10, y: 10, width: 40, height: 40)
            gridContainer.alpha = 0
            
            // Add mini icon placeholders in 2x2 grid
            for i in 0..<4 {
                let miniIcon = UIView()
                let row = i / 2
                let col = i % 2
                miniIcon.frame = CGRect(x: col * 22, y: row * 22, width: 16, height: 16)
                miniIcon.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                miniIcon.layer.cornerRadius = 3
                gridContainer.addSubview(miniIcon)
            }
            
            previewContainer.addSubview(gridContainer)
            
            // Progress ring layer
            let progressLayer = CAShapeLayer()
            let progressPath = UIBezierPath(arcCenter: CGPoint(x: 30, y: 30),
                                           radius: 35,
                                           startAngle: -.pi / 2,
                                           endAngle: 1.5 * .pi,
                                           clockwise: true)
            progressLayer.path = progressPath.cgPath
            progressLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
            progressLayer.fillColor = UIColor.clear.cgColor
            progressLayer.lineWidth = 2
            progressLayer.lineCap = .round
            progressLayer.strokeEnd = 0
            
            previewContainer.layer.addSublayer(progressLayer)
            
            // Add to cell
            cell.contentView.addSubview(previewContainer)
            dropTargetView = previewContainer
            
            // Animate morphing transition
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.5)
            
            // Morph to folder shape
            let folderPath = UIBezierPath(roundedRect: CGRect(x: -5, y: -5, width: 70, height: 70), 
                                         cornerRadius: 22)
            let morphAnimation = CABasicAnimation(keyPath: "path")
            morphAnimation.fromValue = initialPath.cgPath
            morphAnimation.toValue = folderPath.cgPath
            morphAnimation.duration = 0.5
            morphAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            morphAnimation.fillMode = .forwards
            morphAnimation.isRemovedOnCompletion = false
            morphLayer.add(morphAnimation, forKey: "morph")
            
            // Scale pulse
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1.0
            scaleAnimation.toValue = 1.08
            scaleAnimation.duration = 0.8
            scaleAnimation.autoreverses = true
            scaleAnimation.repeatCount = .infinity
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            previewContainer.layer.add(scaleAnimation, forKey: "pulse")
            
            // Progress animation
            let progressAnimation = CABasicAnimation(keyPath: "strokeEnd")
            progressAnimation.fromValue = 0
            progressAnimation.toValue = 1
            progressAnimation.duration = (parent?.stateManager.folderCreationProgress ?? 0) > 0 ? 0.5 : 0
            progressAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            progressAnimation.fillMode = .forwards
            progressAnimation.isRemovedOnCompletion = false
            progressLayer.add(progressAnimation, forKey: "progress")
            
            // Fade in grid
            UIView.animate(withDuration: 0.3, delay: 0.2, options: .curveEaseOut) {
                gridContainer.alpha = 0.6
            }
            
            CATransaction.commit()
            
            // Start folder creation timer in state manager
            if let draggedItem = getItem(at: draggedIndexPath ?? IndexPath(item: 0, section: 0)),
               let targetItem = getItem(at: indexPath) {
                parent?.stateManager.checkFolderCreation(draggedId: draggedItem.id, targetId: targetItem.id)
            }
            
            // iOS-style progressive haptic feedback for folder preview
            HapticManager.selection()
            
            // Build up haptic intensity
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                HapticManager.impact(.light)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                HapticManager.impact(.medium)
                
                // Add subtle continuous feedback
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.prepare()
                
                // Pulse effect
                for i in 0..<3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + (Double(i) * 0.3)) {
                        generator.impactOccurred(intensity: 0.5)
                    }
                }
            }
        }
        
        private func clearDropTargetHighlight() {
            UIView.animate(withDuration: 0.2) {
                self.dropTargetView?.alpha = 0
            } completion: { _ in
                self.dropTargetView?.removeFromSuperview()
                self.dropTargetView = nil
            }
        }
        
        private func endDragging(in collectionView: UICollectionView, velocity: CGPoint = .zero) {
            guard let draggedView = draggedView,
                  let draggedIndexPath = draggedIndexPath else { return }
            
            // Stop auto-scroll
            stopAutoScroll()
            
            // Clear drop target highlight
            clearDropTargetHighlight()
            
            // Check if we're creating a folder
            if let dropTargetId = parent?.stateManager.dropTargetId,
               let draggedItem = getItem(at: draggedIndexPath),
               let targetItem = getAllItems().first(where: { $0.id == dropTargetId }) {
                
                // Folder creation animation
                performFolderCreation(draggedItem: draggedItem, targetItem: targetItem, draggedView: draggedView, in: collectionView)
            } else {
                // Regular drop animation
                performDropAnimation(draggedView: draggedView, at: draggedIndexPath, velocity: velocity, in: collectionView)
            }
        }
        
        private func performDropAnimation(draggedView: UIView, at indexPath: IndexPath, velocity: CGPoint, in collectionView: UICollectionView) {
            // Check if animation is already in progress
            if animationCoordinator.isAnimating("drop-\(indexPath.item)") {
                return
            }
            
            // Get final position
            if let cell = collectionView.cellForItem(at: indexPath) {
                // Calculate momentum-based overshoot
                let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                let momentumScale = 1.0 + min(speed / 5000, 0.05)
                
                // iOS-style drop with physics and polish
                animationCoordinator.performAnimation(id: "drop-\(indexPath.item)", duration: 0.4, animations: {
                    UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: .calculationModeCubic) {
                        // Phase 1: Momentum overshoot with rotation (0-25%)
                        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                            let overshootX = cell.center.x + velocity.x * 0.025
                            let overshootY = cell.center.y + velocity.y * 0.025
                            draggedView.center = CGPoint(x: overshootX, y: overshootY)
                            
                            // Add slight rotation based on velocity
                            let rotation = atan2(velocity.x, 3000) * 0.1
                            draggedView.transform = CGAffineTransform(scaleX: momentumScale, y: momentumScale)
                                .rotated(by: rotation)
                        }
                        
                        // Phase 2: Begin settling (25-50%)
                        UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                            draggedView.center = cell.center
                            draggedView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                            draggedView.layer.shadowOffset = CGSize(width: 0, height: 2)
                            draggedView.layer.shadowOpacity = 0.08
                            draggedView.layer.shadowRadius = 4
                        }
                        
                        // Phase 3: Final settle (50-80%)
                        UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.3) {
                            draggedView.transform = .identity
                            draggedView.layer.shadowOpacity = 0
                            draggedView.layer.shadowRadius = 0
                            draggedView.alpha = 0.5
                        }
                        
                        // Phase 4: Complete transition (80-100%)
                        UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                            draggedView.alpha = 0
                            cell.alpha = 1
                            
                            // Add subtle bounce to cell
                            cell.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                        }
                    }
                    
                    // Cell bounce back
                    UIView.animate(withDuration: 0.15, delay: 0.35, options: .curveEaseOut) {
                        cell.transform = .identity
                    }
                }, completion: {
                    draggedView.removeFromSuperview()
                    self.cleanupDragState()
                    
                    // Subtle haptic on landing
                    HapticManager.impact(.soft)
                })
            }
            
            // Save new positions
            saveItemPositions(in: collectionView)
        }
        
        private func performFolderCreation(draggedItem: SpringboardItem, targetItem: SpringboardItem, draggedView: UIView, in collectionView: UICollectionView) {
            // Get target cell position
            guard let targetIndex = getAllItems().firstIndex(where: { $0.id == targetItem.id }),
                  let targetCell = collectionView.cellForItem(at: IndexPath(item: targetIndex, section: 0)) as? SpringboardIconCell else {
                // Fallback to regular drop
                if let draggedIndex = getAllItems().firstIndex(where: { $0.id == draggedItem.id }) {
                    performDropAnimation(draggedView: draggedView, at: IndexPath(item: draggedIndex, section: 0), velocity: .zero, in: collectionView)
                }
                return
            }
            
            // Create morphing container with glass effect
            let morphContainer = UIView(frame: targetCell.bounds)
            morphContainer.center = targetCell.center
            morphContainer.backgroundColor = .clear
            targetCell.superview?.insertSubview(morphContainer, aboveSubview: targetCell)
            
            // Add subtle glow effect
            let glowView = UIView(frame: morphContainer.bounds.insetBy(dx: -20, dy: -20))
            glowView.center = CGPoint(x: morphContainer.bounds.midX, y: morphContainer.bounds.midY)
            glowView.backgroundColor = UIColor.white
            glowView.layer.cornerRadius = 40
            glowView.layer.shadowColor = UIColor.white.cgColor
            glowView.layer.shadowOffset = .zero
            glowView.layer.shadowRadius = 30
            glowView.layer.shadowOpacity = 0
            morphContainer.insertSubview(glowView, at: 0)
            
            // Create folder shape layer
            let folderLayer = CAShapeLayer()
            folderLayer.frame = morphContainer.bounds
            folderLayer.fillColor = UIColor.white.withAlphaComponent(0.1).cgColor
            folderLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
            folderLayer.lineWidth = 1.5
            
            // Initial paths
            let iconPath = UIBezierPath(roundedRect: CGRect(x: 15, y: 15, width: 30, height: 30), cornerRadius: 6.75)
            let folderPath = UIBezierPath(roundedRect: CGRect(x: -5, y: -5, width: 70, height: 70), cornerRadius: 22)
            folderLayer.path = iconPath.cgPath
            
            morphContainer.layer.addSublayer(folderLayer)
            
            // Create mini icons for the folder preview
            let miniIconsContainer = UIView()
            miniIconsContainer.frame = CGRect(x: 10, y: 10, width: 40, height: 40)
            miniIconsContainer.alpha = 0
            morphContainer.addSubview(miniIconsContainer)
            
            // Add 4 mini icons in 2x2 grid
            for i in 0..<4 {
                let miniIcon = UIView()
                let row = i / 2
                let col = i % 2
                miniIcon.frame = CGRect(x: col * 22, y: row * 22, width: 16, height: 16)
                miniIcon.backgroundColor = i < 2 ? UIColor(white: 0.9, alpha: 0.8) : UIColor(white: 0.7, alpha: 0.6)
                miniIcon.layer.cornerRadius = 3
                miniIconsContainer.addSubview(miniIcon)
            }
            
            // Hide target cell during animation
            targetCell.alpha = 0
            
            // Folder creation animation sequence
            animationCoordinator.performAnimation(id: "folder-creation", duration: 0.7, animations: {
                UIView.animateKeyframes(withDuration: 0.7, delay: 0, options: .calculationModeCubic) {
                    // Phase 1: Icons converge and start morphing (0-30%)
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                        draggedView.center = targetCell.center
                        draggedView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                        draggedView.layer.shadowOpacity = 0
                        
                        // Animate glow appearance
                        glowView.layer.shadowOpacity = 0.3
                        
                        // Start morphing shape
                        CATransaction.begin()
                        CATransaction.setAnimationDuration(0.21)
                        let morphAnimation = CABasicAnimation(keyPath: "path")
                        morphAnimation.toValue = folderPath.cgPath
                        morphAnimation.fillMode = .forwards
                        morphAnimation.isRemovedOnCompletion = false
                        folderLayer.add(morphAnimation, forKey: "morph")
                        CATransaction.commit()
                    }
                    
                    // Phase 2: Dragged icon fades, folder expands (30-50%)
                    UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.2) {
                        draggedView.alpha = 0
                        morphContainer.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                        miniIconsContainer.alpha = 1
                    }
                    
                    // Phase 3: Bounce effect (50-70%)
                    UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.2) {
                        morphContainer.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                        
                        // Rotate mini icons slightly
                        miniIconsContainer.transform = CGAffineTransform(rotationAngle: 0.05)
                    }
                    
                    // Phase 4: Settle to final size (70-100%)
                    UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                        morphContainer.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        miniIconsContainer.transform = .identity
                    }
                }
            }, completion: {
                // Clean up
                draggedView.removeFromSuperview()
                morphContainer.removeFromSuperview()
                targetCell.alpha = 1
                self.cleanupDragState()
                
                // Trigger folder creation in view model
                Task {
                    await self.createFolder(from: draggedItem, and: targetItem)
                    
                    // Reload to show new folder
                    await MainActor.run {
                        collectionView.reloadData()
                    }
                }
            })
            
            // iOS-native haptic sequence for folder creation
            // Initial contact
            HapticManager.impact(.light)
            
            // Build up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                HapticManager.impact(.medium)
            }
            
            // Peak moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                HapticManager.impact(.heavy)
            }
            
            // Success notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HapticManager.notification(.success)
            }
        }
        
        private func cleanupDragState() {
            self.draggedView = nil
            self.draggedIndexPath = nil
            self.originalCenter = nil
            
            // Update state manager
            parent?.stateManager.endDragging()
        }
        
        private func createFolder(from item1: SpringboardItem, and item2: SpringboardItem) async {
            // Get apps from items
            var app1: BookmarkedApp?
            var app2: BookmarkedApp?
            
            switch item1 {
            case .app(let app):
                app1 = app
            case .folder:
                return // TODO: Handle folder merging
            }
            
            switch item2 {
            case .app(let app):
                app2 = app
            case .folder:
                return // TODO: Handle adding to folder
            }
            
            guard let app1 = app1, let app2 = app2 else { return }
            
            // Create folder with smart naming
            let folderName = suggestFolderName(for: [app1, app2])
            let folderColor = suggestFolderColor(for: [app1, app2])
            
            await parent?.viewModel.createFolder(name: folderName, color: folderColor)
            
            // Wait for folder creation
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            // Move apps to folder
            if let newFolder = parent?.viewModel.folders.last {
                await parent?.viewModel.moveAppToFolder(app1, folderId: newFolder.id, position: 0)
                await parent?.viewModel.moveAppToFolder(app2, folderId: newFolder.id, position: 1)
            }
        }
        
        private func suggestFolderName(for apps: [BookmarkedApp]) -> String {
            // Smart folder naming based on app categories
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
        
        private func suggestFolderColor(for apps: [BookmarkedApp]) -> String {
            // Suggest colors based on category
            let colors = ["#6366F1", "#8B5CF6", "#3B82F6", "#10B981", "#F59E0B", "#EF4444"]
            return colors.randomElement() ?? "#6366F1"
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
        
        private func getItem(at indexPath: IndexPath) -> SpringboardItem? {
            let allItems = getAllItems()
            guard indexPath.item < allItems.count else { return nil }
            return allItems[indexPath.item]
        }
        
        private func getAllItems() -> [SpringboardItem] {
            var items: [SpringboardItem] = []
            
            // Add apps not in folders
            let unfolderedApps = parent?.apps.filter { $0.folderId == nil } ?? []
            items.append(contentsOf: unfolderedApps.map { .app($0) })
            
            // Add folders
            items.append(contentsOf: parent?.folders.map { .folder($0) } ?? [])
            
            // Sort by position
            return items.sorted { $0.position < $1.position }
        }
        
        private func saveItemPositions(in collectionView: UICollectionView) {
            // Update positions based on current order
            let items = getAllItems()
            
            Task {
                // Update app positions
                let apps = items.compactMap { item -> String? in
                    if case .app(let app) = item { return app.id }
                    return nil
                }
                
                if !apps.isEmpty {
                    await parent?.viewModel.reorderApps(apps)
                }
                
                // Update folder positions
                let folders = items.compactMap { item -> String? in
                    if case .folder(let folder) = item { return folder.id }
                    return nil
                }
                
                if !folders.isEmpty {
                    await parent?.viewModel.reorderFolders(folders)
                }
            }
        }
        
        // MARK: - UICollectionViewDataSource
        
        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return 1
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return getAllItems().count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IconCell", for: indexPath) as! SpringboardIconCell
            
            if let item = getItem(at: indexPath),
               let stateManager = parent?.stateManager,
               let viewModel = parent?.viewModel {
                cell.configure(with: item, stateManager: stateManager, viewModel: viewModel)
            }
            
            return cell
        }
        
        // MARK: - UICollectionViewDelegateFlowLayout
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            // iOS standard icon size
            return CGSize(width: 60, height: 88) // Icon + label
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let parent = parent else { return }
            guard !parent.stateManager.isEditing else { return }
            
            if let item = getItem(at: indexPath) {
                switch item {
                case .app(let app):
                    parent.onAppTap(app)
                case .folder(let folder):
                    parent.onFolderTap(folder)
                }
            }
        }
        
        // MARK: - UICollectionViewDataSourcePrefetching
        
        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            // Performance: Preload resources for upcoming cells
            for indexPath in indexPaths {
                if let item = getItem(at: indexPath) {
                    switch item {
                    case .app(let app):
                        // Preload app icon
                        if let iconUrl = app.iconUrl, let url = URL(string: iconUrl) {
                            // Warm up image cache
                            URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
                        }
                    case .folder:
                        // Folders use system resources, no prefetch needed
                        break
                    }
                }
            }
        }
        
        func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
            // Cancel any ongoing prefetch operations if needed
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition for drag gestures
            return gestureRecognizer == panGesture && otherGestureRecognizer == longPressGesture
        }
    }
}

// MARK: - Springboard Flow Layout

class SpringboardFlowLayout: UICollectionViewFlowLayout {
    // Performance: Cache layout attributes
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentSize: CGSize = .zero
    
    override init() {
        super.init()
        
        // Configure layout
        scrollDirection = .horizontal
        minimumLineSpacing = 16
        minimumInteritemSpacing = 24
        
        // iOS standard margins
        let sideMargin: CGFloat = UIScreen.main.bounds.width >= 428 ? 34 : (UIScreen.main.bounds.width >= 390 ? 27 : 24)
        sectionInset = UIEdgeInsets(top: 10, left: sideMargin, bottom: 30, right: sideMargin)
        
        // Calculate item size
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = screenWidth - (sideMargin * 2) - (minimumInteritemSpacing * 3)
        let itemWidth = availableWidth / 4
        itemSize = CGSize(width: itemWidth, height: itemWidth + 28) // Icon + label
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepare() {
        super.prepare()
        
        // Performance: Cache layout calculations
        guard let collectionView = collectionView else { return }
        cachedAttributes.removeAll()
        
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        let pageWidth = collectionView.bounds.width
        let itemsPerPage = 24 // 6 rows × 4 columns
        let numberOfPages = Int(ceil(Double(numberOfItems) / Double(itemsPerPage)))
        
        contentSize = CGSize(
            width: pageWidth * CGFloat(numberOfPages),
            height: collectionView.bounds.height
        )
    }
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // Performance: Only invalidate when size changes
        return collectionView?.bounds.size != newBounds.size
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        // Enhanced paging with velocity consideration
        let pageWidth = collectionView?.bounds.width ?? 0
        let currentPage = proposedContentOffset.x / pageWidth
        
        // Consider velocity for better responsiveness
        let velocityThreshold: CGFloat = 0.2
        var targetPage: CGFloat
        
        if abs(velocity.x) > velocityThreshold {
            targetPage = velocity.x > 0 ? ceil(currentPage) : floor(currentPage)
        } else {
            targetPage = round(currentPage)
        }
        
        let targetX = targetPage * pageWidth
        return CGPoint(x: targetX, y: proposedContentOffset.y)
    }
}

// MARK: - Springboard Icon Cell

class SpringboardIconCell: UICollectionViewCell {
    private var iconView: UIView?
    private var item: SpringboardItem?
    private var hostingController: UIHostingController<AnyView>?
    
    // Performance optimization: Reuse hosting controllers
    private static let hostingControllerCache = NSCache<NSString, UIHostingController<AnyView>>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Clean up for reuse
        iconView?.removeFromSuperview()
        iconView = nil
        
        // Remove hosting controller
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        
        // Reset item
        item = nil
        
        // Cancel any ongoing animations
        layer.removeAllAnimations()
        contentView.layer.removeAllAnimations()
    }
    
    private func setupViews() {
        // Clear background
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Performance: Disable default animations
        contentView.layer.shouldRasterize = true
        contentView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    func configure(with item: SpringboardItem, stateManager: SpringboardStateManager, viewModel: AppsViewModel) {
        self.item = item
        
        // Performance: Remove old views only if necessary
        if let existingView = iconView, hostingController != nil {
            // Update existing view if possible
            configureExistingView(item: item, stateManager: stateManager, viewModel: viewModel)
            return
        }
        
        // Remove old icon view
        iconView?.removeFromSuperview()
        
        // Create appropriate SwiftUI view with performance optimizations
        let hostingController: UIHostingController<AnyView>
        
        switch item {
        case .app(let app):
            let view = LiquidGlassAppIcon(
                app: app,
                iconSize: 60,
                isEditMode: .constant(stateManager.isEditing),
                isDragging: stateManager.iconStates[item.id]?.isDragging ?? false,
                isDropTarget: stateManager.dropTargetId == item.id,
                onTap: {},
                onDelete: { viewModel.deleteApp(app) }
            )
            .wiggle(isActive: stateManager.isEditing && !(stateManager.iconStates[item.id]?.isDragging ?? false))
            .environmentObject(stateManager)
            .drawingGroup() // Performance: Render as single layer
            
            hostingController = UIHostingController(rootView: AnyView(view))
            
        case .folder(let folder):
            let view = LiquidGlassFolderIcon(
                folder: folder,
                apps: viewModel.appsInFolder(folder.id),
                iconSize: 81, // 60 * 1.35 for folder scale
                isEditMode: .constant(stateManager.isEditing),
                isDragging: stateManager.iconStates[item.id]?.isDragging ?? false,
                isDropTarget: stateManager.dropTargetId == item.id,
                onTap: {},
                onDelete: { viewModel.deleteFolder(folder) }
            )
            .wiggle(isActive: stateManager.isEditing && !(stateManager.iconStates[item.id]?.isDragging ?? false))
            .environmentObject(stateManager)
            .drawingGroup() // Performance: Render as single layer
            
            hostingController = UIHostingController(rootView: AnyView(view))
        }
        
        // Store the hosting controller
        self.hostingController = hostingController
        
        // Performance: Disable SwiftUI automatic animations
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = contentView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Performance: Disable implicit animations
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentView.addSubview(hostingController.view)
        CATransaction.commit()
        
        iconView = hostingController.view
    }
    
    private func configureExistingView(item: SpringboardItem, stateManager: SpringboardStateManager, viewModel: AppsViewModel) {
        // Performance: Update existing view without recreating
        guard let controller = hostingController else { return }
        
        // Update the hosting controller's root view
        switch item {
        case .app(let app):
            let view = LiquidGlassAppIcon(
                app: app,
                iconSize: 60,
                isEditMode: .constant(stateManager.isEditing),
                isDragging: stateManager.iconStates[item.id]?.isDragging ?? false,
                isDropTarget: stateManager.dropTargetId == item.id,
                onTap: {},
                onDelete: { viewModel.deleteApp(app) }
            )
            .wiggle(isActive: stateManager.isEditing && !(stateManager.iconStates[item.id]?.isDragging ?? false))
            .environmentObject(stateManager)
            .drawingGroup()
            
            controller.rootView = AnyView(view)
            
        case .folder(let folder):
            let view = LiquidGlassFolderIcon(
                folder: folder,
                apps: viewModel.appsInFolder(folder.id),
                iconSize: 81,
                isEditMode: .constant(stateManager.isEditing),
                isDragging: stateManager.iconStates[item.id]?.isDragging ?? false,
                isDropTarget: stateManager.dropTargetId == item.id,
                onTap: {},
                onDelete: { viewModel.deleteFolder(folder) }
            )
            .wiggle(isActive: stateManager.isEditing && !(stateManager.iconStates[item.id]?.isDragging ?? false))
            .environmentObject(stateManager)
            .drawingGroup()
            
            controller.rootView = AnyView(view)
        }
    }
}
