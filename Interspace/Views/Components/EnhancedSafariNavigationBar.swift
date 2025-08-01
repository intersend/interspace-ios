import SwiftUI
import UIKit

// MARK: - Navigation Bar State
enum NavigationBarState {
    case expanded      // 44pt - Full height with all controls
    case compact       // 36pt - Medium height
    case ultraCompact  // 28pt - Minimal height, only essentials
    
    var height: CGFloat {
        switch self {
        case .expanded:
            return 44
        case .compact:
            return 36
        case .ultraCompact:
            return 28
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .expanded:
            return 15
        case .compact:
            return 14
        case .ultraCompact:
            return 13
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .expanded:
            return 18
        case .compact:
            return 16
        case .ultraCompact:
            return 14
        }
    }
    
    var buttonSize: CGFloat {
        switch self {
        case .expanded:
            return 44
        case .compact:
            return 36
        case .ultraCompact:
            return 28
        }
    }
}

// MARK: - Enhanced Safari Navigation Bar
@available(iOS 15.0, *)
struct EnhancedSafariNavigationBar: View {
    @ObservedObject var webPage: WebPage
    @Binding var searchText: String
    @Binding var navigationState: NavigationBarState
    @Binding var scrollOffset: CGFloat
    @Binding var isScrollingUp: Bool
    @Binding var showSearchOverlay: Bool
    
    let onDismiss: () -> Void
    let onShare: () -> Void
    let onAddApp: () -> Void
    var onAddToProfile: (() -> Void)? = nil
    
    @State private var urlFieldScale: CGFloat = 1.0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var scrollVelocity: CGFloat = 0
    @State private var lastScrollTime: Date = Date()
    
    // Thresholds for state transitions
    private let compactThreshold: CGFloat = 50
    private let ultraCompactThreshold: CGFloat = 150
    private let scrollUpThreshold: CGFloat = -20
    
    private var displayText: String {
        if let url = webPage.url {
            return url.host ?? url.absoluteString
        }
        return "Search or enter website name"
    }
    
    private var isSecure: Bool {
        webPage.url?.scheme == "https"
    }
    
    // Show search button only when at the very top
    private var shouldShowSearchButton: Bool {
        scrollOffset <= 5 && navigationState == .expanded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Pull-down search indicator (only visible when pulling down at top)
            if scrollOffset < -10 && navigationState == .expanded {
                searchPullIndicator
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Main navigation bar
            HStack(spacing: navigationState == .ultraCompact ? 12 : 16) {
                // Navigation buttons (hide in ultra-compact)
                if navigationState != .ultraCompact {
                    navigationButtons
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
                
                // URL Field
                urlField
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal, navigationState == .ultraCompact ? 12 : 16)
            .frame(height: navigationState.height)
            .padding(.vertical, 4)
        }
        .background(
            SafariNavigationBackground()
        )
        .onChange(of: scrollOffset) { newValue in
            handleScrollChange(newValue)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: navigationState)
    }
    
    // MARK: - Subviews
    
    private var searchPullIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.6))
            
            Text("Pull to Search")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .padding(.vertical, 8)
        .scaleEffect(min(1.0, max(0.8, 1.0 + (scrollOffset / 100))))
        .opacity(min(1.0, max(0.0, -scrollOffset / 50)))
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 20) {
            SafariButton(
                icon: "chevron.left",
                size: navigationState.iconSize,
                buttonSize: navigationState.buttonSize,
                isEnabled: webPage.canGoBack,
                action: { webPage.goBack() }
            )
            
            SafariButton(
                icon: "chevron.right",
                size: navigationState.iconSize,
                buttonSize: navigationState.buttonSize,
                isEnabled: webPage.canGoForward,
                action: { webPage.goForward() }
            )
        }
    }
    
    private var urlField: some View {
        Button(action: {
            // Only show search when at top
            if scrollOffset <= 5 {
                HapticManager.impact(.light)
                showSearchOverlay = true
            }
        }) {
            HStack(spacing: 6) {
                if isSecure && navigationState != .ultraCompact {
                    Image(systemName: "lock.fill")
                        .font(.system(size: navigationState.fontSize - 5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                Text(displayText)
                    .font(.system(size: navigationState.fontSize - 2, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if webPage.isLoading {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: navigationState.fontSize - 4, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                        .rotationEffect(.degrees(webPage.isLoading ? 360 : 0))
                        .animation(webPage.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: webPage.isLoading)
                }
                
                // Search icon only when at top
                if shouldShowSearchButton {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: navigationState.fontSize - 3, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.5))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, navigationState == .ultraCompact ? 10 : 14)
            .frame(height: navigationState == .ultraCompact ? 24 : 32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: navigationState == .ultraCompact ? 12 : 16, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            )
        }
        .scaleEffect(urlFieldScale)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                urlFieldScale = pressing ? 0.96 : 1.0
            }
        }, perform: {})
        .disabled(scrollOffset > 5 && navigationState != .expanded)
    }
    
    private var actionButtons: some View {
        HStack(spacing: navigationState == .ultraCompact ? 16 : 20) {
            // Share Button (hide in ultra-compact)
            if navigationState != .ultraCompact {
                SafariButton(
                    icon: "square.and.arrow.up",
                    size: navigationState.iconSize,
                    buttonSize: navigationState.buttonSize,
                    isEnabled: webPage.url != nil,
                    action: onShare
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            // Quick Add Button (always visible but smaller in ultra-compact)
            SafariButton(
                icon: "plus.app",
                size: navigationState.iconSize,
                buttonSize: navigationState.buttonSize,
                isEnabled: webPage.url != nil,
                action: onAddApp
            )
            
            // Menu/Tab Button
            Button(action: navigationState == .ultraCompact ? onDismiss : showMenu) {
                Image(systemName: navigationState == .ultraCompact ? "xmark" : "ellipsis")
                    .font(.system(size: navigationState.iconSize, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: navigationState.buttonSize, height: navigationState.buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SafariButtonStyle())
        }
    }
    
    // MARK: - Methods
    
    private func handleScrollChange(_ newOffset: CGFloat) {
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastScrollTime)
        
        if timeDelta > 0 {
            let offsetDelta = newOffset - previousScrollOffset
            scrollVelocity = offsetDelta / CGFloat(timeDelta)
            
            // Determine scroll direction
            isScrollingUp = offsetDelta < 0
            
            // Update navigation state based on offset and velocity
            updateNavigationState(offset: newOffset, velocity: scrollVelocity)
            
            previousScrollOffset = newOffset
            lastScrollTime = currentTime
        }
        
        // Check for elastic overscroll at top
        if newOffset < -50 && navigationState == .expanded {
            // Trigger search on significant pull-down
            showSearchOverlay = true
            HapticManager.impact(.medium)
        }
    }
    
    private func updateNavigationState(offset: CGFloat, velocity: CGFloat) {
        // At the very top, always show expanded
        if offset <= 0 {
            navigationState = .expanded
            return
        }
        
        // Fast scroll down - quickly transition to ultra-compact
        if velocity > 500 && offset > ultraCompactThreshold / 2 {
            navigationState = .ultraCompact
            return
        }
        
        // Fast scroll up - quickly transition to expanded if near top
        if velocity < -300 && offset < compactThreshold {
            navigationState = .expanded
            return
        }
        
        // Threshold-based transitions
        if offset > ultraCompactThreshold {
            navigationState = .ultraCompact
        } else if offset > compactThreshold {
            navigationState = .compact
        } else {
            navigationState = .expanded
        }
    }
    
    private func showMenu() {
        // Implementation for menu display
        HapticManager.impact(.light)
    }
}

// MARK: - Enhanced Safari Button
private struct SafariButton: View {
    let icon: String
    let size: CGFloat
    let buttonSize: CGFloat
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if isEnabled {
                HapticManager.impact(.light)
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
                .foregroundColor(isEnabled ? .white : Color.white.opacity(0.3))
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .buttonStyle(SafariButtonStyle())
    }
}