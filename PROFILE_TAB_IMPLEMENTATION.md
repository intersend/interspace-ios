# Profile Tab Implementation Specification

## Overview
The Profile tab implements iOS 26's Liquid Glass design language with military-grade precision. Every interaction, animation, and visual element has been engineered to match Apple's exacting standards.

## Component Specifications

### 1. Profile Card Component

#### Dimensions
- Card size: 358pt × 180pt
- Corner radius: 24pt (continuous curve using squircle formula)
- Edge insets: 16pt from screen edges
- Shadow: color: black(0.15), radius: 20pt, offset: (0, 10pt)

#### Glass Layer Composition
```
Layer Stack (bottom to top):
1. Base layer: .ultraThinMaterial with 85% opacity
2. Gradient overlay: Linear gradient white(0.15) to white(0.05)
3. Profile image container: 64pt × 64pt, offset: (24pt, 24pt)
4. Text container: Dynamic width, offset: (104pt, 32pt)
5. Action buttons: 44pt × 44pt, trailing edge -16pt
6. Border layer: 0.5pt white(0.2) continuous curve
7. Specular highlight: 1pt white(0.4) top edge only
```

#### Profile Image
- Size: 64pt × 64pt
- Corner radius: 32pt (perfect circle)
- Border: 2pt white(0.3) with glass effect
- Shadow: Subtle depth shadow, radius: 4pt, black(0.1)
- Placeholder: Generated gradient based on name hash

#### Typography
- Name: SF Pro Display Semibold, 20pt, primary label color
- Username: SF Pro Text Regular, 15pt, secondary label color
- Wallet address: SF Mono Regular, 13pt, tertiary label color
- Vertical spacing: 4pt between elements

### 2. Profile Switcher Mechanics

#### Grid Layout
- Columns: 2
- Row height: 196pt (card + 16pt padding)
- Horizontal spacing: 16pt
- Vertical spacing: 16pt
- Maximum visible rows: 3.5 (encourages discovery)

#### Selection Animation
```
Timing: Spring(response: 0.5, damping: 0.8)
1. Scale down to 0.95 (0.1s)
2. Haptic: Medium impact
3. Scale up to 1.02 (0.2s)
4. Settle to 1.0 (0.2s)
5. Navigation transition begins
```

#### Scroll Behavior
- Deceleration rate: UIScrollView.DecelerationRate.fast
- Rubber band effect: Standard iOS behavior
- Scroll indicators: Hidden
- Page snapping: Disabled (continuous scroll)

### 3. Add Profile Flow

#### Plus Button
- Size: 56pt × 56pt
- Position: Bottom-right, offset: (-24pt, -24pt)
- Background: Liquid glass with accent color tint
- Icon: SF Symbol "plus", 24pt, white
- Shadow: color: accent(0.3), radius: 12pt, offset: (0, 6pt)

#### Tap Animation
```
1. Scale to 0.9 with spring (0.15s)
2. Haptic: Light impact
3. Scale to 1.1 (0.2s)
4. Return to 1.0 while sheet presents
```

#### Creation Sheet
- Presentation: Full screen cover with spring
- Background: .thick material
- Corner radius: 38pt (top corners only)
- Drag to dismiss: Enabled with rubber band

### 4. Edit Mode Specifications

#### Activation
- Method: Long press on any profile card
- Duration: 0.5s
- Haptic feedback: Medium impact on activation
- Visual feedback: Card lifts with shadow increase

#### Delete Button
- Size: 28pt × 28pt
- Position: Top-right corner, offset: (-8pt, -8pt)
- Background: Red (#FF3B30) with 100% opacity
- Icon: SF Symbol "xmark", 16pt, white, bold
- No transparency or glass effect (solid red)

#### Card Wiggle Animation
```
CAKeyframeAnimation:
- Rotation: ±2.5° (0.0436 radians)
- Duration: 0.13s per complete cycle
- Timing: Linear with slight ease
- Y-axis translation: ±2pt
- Random phase offset per card: 0-0.3s
```

#### Reorder Mechanics
- Drag threshold: 10pt movement
- Lift animation: Scale to 1.05, shadow radius to 30pt
- Other cards: Animate position with spring(0.4, 0.8)
- Drop zones: Highlight with 0.1 opacity accent color
- Auto-scroll: 50pt from top/bottom edges at 150pt/s

### 5. Account Management

#### Add Account Types
```
OAuth Providers:
- Google: Full OAuth 2.0 flow
- Apple: Sign in with Apple
- GitHub: OAuth with scopes
- Twitter/X: OAuth 1.0a

Wallet Connection:
- MetaMask: WalletConnect v2
- Coinbase: Deep link integration
- Hardware wallets: WebUSB support

Email Authentication:
- Magic link with 6-digit code
- Code input: Native iOS code field
- Expiry: 10 minutes
- Rate limiting: 3 attempts per hour
```

#### Account Removal
- Swipe to delete: Disabled (too easy to trigger accidentally)
- Edit mode only: Tap delete button
- Confirmation: Action sheet with destructive option
- Animation: Fade out with scale to 0.8
- Haptic: Heavy impact on confirmation

### 6. Glass Effects Implementation

#### Material Layers
```swift
// Profile card glass effect
ZStack {
    // Base glass
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(.ultraThinMaterial)
        .opacity(0.85)
    
    // Gradient overlay
    LinearGradient(
        colors: [.white.opacity(0.15), .white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Inner shadow for depth
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(.white.opacity(0.2), lineWidth: 0.5)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .blendMode(.overlay)
}
```

#### Dynamic Tinting
- Extract dominant color from profile image
- Apply at 20% opacity to glass material
- Animate color changes with 0.3s duration
- Respect system accessibility settings

### 7. Spring Animation Parameters

#### Standard Springs
```swift
// Navigation and transitions
.spring(response: 0.55, dampingFraction: 0.825)

// Quick interactions (taps)
.spring(response: 0.3, dampingFraction: 0.7)

// Smooth transitions (no bounce)
.spring(response: 0.4, dampingFraction: 1.0)

// Delete confirmations
.spring(response: 0.6, dampingFraction: 0.6)
```

### 8. Haptic Feedback Patterns

#### Feedback Types
```swift
// Light Impact
- Profile card tap
- Switch between profiles
- Scroll to top

// Medium Impact  
- Long press activation
- Add profile button tap
- Successful authentication

// Heavy Impact
- Profile deletion
- Error states
- Biometric authentication

// Selection Changed
- Hovering over delete button
- Text field focus
```

### 9. Performance Optimizations

#### Image Handling
- Lazy load profile images
- Cache rendered glass effects
- Downscale images to 2x display size
- Use CALayer rasterization for static elements

#### Animation Performance
- Reduce animation complexity in low power mode
- Disable wiggle on devices with reduced motion
- Use GPU-accelerated layers for glass effects
- Batch layout updates during reorder

#### Memory Management
- Limit cached profiles to 10
- Purge unused glass render caches
- Cancel image loads when scrolling fast
- Reuse profile card views in switcher

### 10. Accessibility

#### VoiceOver
- Profile cards: "Name, username, profile N of M"
- Delete button: "Delete profile name"
- Add button: "Add new profile"
- Actions: Available through rotor

#### Dynamic Type
- Support sizes: .xSmall to .xxxLarge
- Card height adjusts with text size
- Maintain 64pt image size
- Wrap username if needed

#### Reduce Motion
- Disable wiggle animation
- Use fade transitions instead of spring
- Minimize parallax effects
- Keep haptic feedback

## Edge Cases

### Empty State
- Show single "Add Profile" card
- Centered in view
- Pulsing animation on plus icon
- Instructional text: SF Pro Display, 17pt

### Maximum Profiles (10)
- Hide add button
- Show alert on attempt to add
- Suggest removing unused profiles
- No wiggle on last profile if it's active

### Network Errors
- Retry with exponential backoff
- Show inline error states
- Cache last known good state
- Allow offline profile switching

### Authentication Failures
- Clear error messages
- Highlight problematic fields
- Shake animation on error
- Maximum 3 attempts before lockout

## Testing Checklist

- [ ] Glass effects render correctly on all devices
- [ ] Wiggle animation maintains 60fps
- [ ] Haptic feedback triggers at correct moments
- [ ] Profile switching completes in <0.5s
- [ ] Delete confirmation prevents accidents
- [ ] Accessibility features work correctly
- [ ] Memory usage stays under 50MB
- [ ] No animation hitches during scroll
- [ ] Edit mode activates reliably
- [ ] All error states handled gracefully