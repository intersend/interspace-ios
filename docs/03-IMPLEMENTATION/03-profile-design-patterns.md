# Profile Page Design Patterns

## Overview
This document analyzes native iOS design patterns for profile management interfaces, reverse-engineering Apple's Settings app and iOS 26 Liquid Glass implementation with military-grade precision.

## Native iOS Settings App Analysis

### Apple ID Interface Design
Based on iOS 18 Settings app structure:

```
Profile Header Section:
- Cell height: 84pt minimum
- Profile image: 64pt × 64pt circle
- Image position: 16pt leading margin
- Text container: 104pt leading offset
- Name typography: SF Pro Display Semibold, 20pt
- Secondary text: SF Pro Text Regular, 15pt
- Chevron: 14pt, tertiary label color
- Vertical padding: 12pt top/bottom
```

### Inset Grouped Table View Specifications
```
Container Margins:
- iPhone: 20pt horizontal margins
- Safe area insets: Automatic
- Section spacing: 35pt between groups
- Header spacing: 8pt below section header

Cell Design:
- Background: secondarySystemGroupedBackground
- Corner radius: 10pt (continuous curve)
- Minimum height: 44pt
- Text insets: 16pt horizontal
- Separator insets: 16pt leading
```

### Typography Hierarchy
```
Primary Text (Account Names):
- Font: SF Pro Text Regular, 17pt
- Color: Primary label (.white in dark mode)
- Line spacing: 22pt

Secondary Text (Details):
- Font: SF Pro Text Regular, 15pt
- Color: Secondary label (.systemGray in dark mode)
- Line spacing: 20pt

Tertiary Text (Addresses):
- Font: SF Mono Regular, 13pt
- Color: Tertiary label (.systemGray2 in dark mode)
- Letter spacing: -0.08pt

Section Headers:
- Font: SF Pro Text Regular, 13pt
- Weight: .medium
- Color: Secondary label
- Case: UPPERCASE
- Margins: 16pt horizontal, 6pt vertical
```

## Profile Card Design Patterns

### Glass Card Component Structure
```
Layer Architecture:
1. Base container (108pt height)
   - Corner radius: 16pt continuous
   - Shadow: black(0.25), radius: 20pt, offset: (0, 8pt)

2. Glass background layer
   - Material: .ultraThinMaterial
   - Tint: Dynamic from profile color
   - Opacity: 0.8

3. Content overlay
   - Padding: 20pt all sides
   - Layout: Leading image + trailing content

4. Interactive highlight
   - Pressed state: white(0.1) overlay
   - Scale: 0.98 on touch down
   - Duration: 0.1s

5. Border definition
   - Stroke: white(0.15), 0.5pt
   - Inner shadow: black(0.05), 1pt inset
```

### Profile Image Specifications
```
Dimensions: 60pt × 60pt
Corner radius: 30pt (perfect circle)
Border: 2pt white(0.3)
Shadow: black(0.2), radius: 6pt, offset: (0, 3pt)

Fallback Generation:
- Gradient based on name hash
- Two-color linear gradient at 135°
- Color palette: iOS accent colors
- Initial letter overlay: SF Pro Display Bold, 24pt
```

## Authentication Interface Patterns

### Sign in with Apple Button
```
Standard Implementation:
- Height: 44pt minimum
- Corner radius: 8pt
- Background: .black
- Text: SF Pro Text Medium, 17pt
- Icon: Apple logo, 18pt, white
- Content spacing: 8pt between icon and text
- Horizontal padding: 16pt
```

### OAuth Provider Buttons
```
Google:
- Background: .white
- Text color: .black
- Icon: Google G logo, 18pt
- Border: 1pt gray(0.3)

GitHub:
- Background: .black
- Text color: .white
- Icon: GitHub mark, 18pt

Apple:
- Background: .black
- Text color: .white
- Icon: Apple logo, 18pt
```

### Biometric Authentication UI
```
Face ID Prompt:
- Modal presentation: .formSheet
- Background: .systemGroupedBackground
- Icon: Face ID glyph, 64pt, blue
- Title: SF Pro Display Semibold, 20pt
- Description: SF Pro Text Regular, 17pt
- Action area: 44pt minimum touch target

Touch ID Prompt:
- System-provided interface
- Cannot be customized
- Automatic fallback to passcode
```

## List Management Patterns

### Account Rows
```
Structure:
- Height: 60pt minimum
- Leading image: 40pt × 40pt
- Image corner radius: 8pt
- Text container: 60pt leading offset
- Primary text: Account name/type
- Secondary text: Username/address
- Trailing element: Chevron or switch

Wallet Account Icons:
- MetaMask: Custom asset, 40pt
- Coinbase: Custom asset, 40pt
- Hardware: SF Symbol "externaldrive", 40pt

Social Account Icons:
- Background circle: Provider color(0.15)
- Icon: SF Symbol or custom, 20pt
- Colors: Brand-specific
```

### Section Organization
```
Header Pattern:
- Text: Uppercase, 13pt medium
- Color: Secondary label
- Margins: 16pt horizontal, 8pt top, 6pt bottom

Content Grouping:
1. Profile management (primary account)
2. Connected accounts (wallets)
3. Social authentication
4. Settings and preferences
5. Destructive actions (logout)
```

## Interactive Patterns

### Add Account Flow
```
Trigger Button:
- Position: Navigation bar trailing
- Style: Circular, 36pt diameter
- Background: white(0.15)
- Icon: Plus, 18pt medium weight
- Touch feedback: Scale to 0.9, medium haptic

Sheet Presentation:
- Style: .formSheet
- Detents: [.medium, .large]
- Drag indicator: Visible
- Background: Thick material
```

### Profile Switching
```
Picker Interface:
- Grid layout: 2 columns
- Cell size: 160pt × 100pt
- Spacing: 12pt horizontal/vertical
- Selection indicator: Blue border, 2pt
- Animation: Spring(0.5, 0.8)

Active Profile Indicator:
- Checkmark overlay: Blue circle
- Position: Top-right corner
- Size: 24pt diameter
- Icon: Checkmark, 12pt, white
```

### Account Management Actions
```
Swipe Actions (iOS Native):
- Edit: Blue background
- Delete: Red background
- Icon size: 20pt
- Haptic: Selection feedback

Context Menu (3D Touch):
- View details
- Set as primary
- Edit account
- Remove account
- Blur background: Ultra thick material
```

## Error States and Feedback

### Loading States
```
Skeleton Loading:
- Shimmer animation
- Gray(0.2) base color
- Gray(0.3) highlight color
- Animation duration: 1.5s
- Ease timing: ease-in-out

Progress Indicators:
- Activity indicator: 20pt
- Color: Secondary label
- Position: Cell center
```

### Error Messages
```
Inline Errors:
- Text color: System red
- Font: SF Pro Text Regular, 15pt
- Icon: Exclamation triangle, 16pt
- Background: Red(0.1)
- Corner radius: 8pt
- Padding: 12pt

Network Errors:
- Banner presentation
- Auto-dismiss: 5 seconds
- Retry action available
- Haptic: Error notification
```

## Animation Specifications

### Spring Parameters
```
Standard Cell Animation:
- Response: 0.5s
- Damping ratio: 0.8
- Initial velocity: 0

Quick Feedback:
- Response: 0.3s
- Damping ratio: 0.7
- Initial velocity: 0

Smooth Transitions:
- Response: 0.4s
- Damping ratio: 1.0
- Initial velocity: 0
```

### Haptic Feedback Mapping
```
Selection Actions:
- Profile tap: Light impact
- Account row tap: Light impact
- Add button: Medium impact

State Changes:
- Profile switch: Selection feedback
- Account connection: Success feedback
- Authentication success: Success feedback

Errors:
- Login failure: Error feedback
- Network error: Error feedback
- Validation error: Warning feedback
```

## Accessibility Patterns

### VoiceOver Support
```
Profile Card:
"Profile card, John Doe, 0x1234...5678, button"

Account Row:
"MetaMask wallet, Primary account, 0xabcd...efgh, button"

Action Button:
"Add account, button"

Header:
"Accounts, heading"
```

### Dynamic Type Support
```
Scaling Behavior:
- Text: Scales with user preference
- Icons: Fixed size (accessibility exception)
- Touch targets: Minimum 44pt maintained
- Layout: Vertical when text too large

Content Categories:
- Large Title: Profile name
- Body: Account names
- Caption 1: Addresses
- Caption 2: Secondary info
```

### Reduced Motion
```
Alternative Animations:
- No spring bounces
- Fade transitions only
- Static shadows
- No shimmer effects
- Instant feedback only
```

## Security UI Patterns

### Sensitive Data Display
```
Address Masking:
- Pattern: "0x1234...5678"
- Monospace font required
- Tap to reveal full address
- Auto-hide after 3 seconds

Biometric Prompts:
- System-provided interfaces only
- No custom biometric UI
- Fallback to passcode always available
- Clear reason strings required
```

### Authentication States
```
Unauthenticated:
- Gray overlay on sensitive data
- Lock icon overlay
- "Tap to authenticate" label

Authenticated:
- Normal data display
- Auto-lock after inactivity
- Session timeout: 5 minutes
```

## Performance Requirements

### Rendering Targets
```
Frame Rates:
- List scrolling: 60fps minimum
- Profile switching: 60fps required
- Glass effects: 60fps required
- Background blur: 30fps acceptable

Memory Limits:
- Profile images: 10MB cache
- Glass effect renders: 25MB cache
- Total profile data: 50MB maximum
```

### Optimization Strategies
```
Image Handling:
- Lazy load off-screen profiles
- Downscale to 2x screen resolution
- Cache rendered glass effects
- Purge on memory warnings

Data Management:
- Paginate large account lists
- Cache recent authentication states
- Debounce network requests
- Cancel obsolete requests
```

## Testing Checklist

- [ ] Profile cards render glass effects correctly
- [ ] Account lists scroll smoothly at 60fps
- [ ] Authentication flows complete without hitches
- [ ] Biometric prompts appear consistently
- [ ] Error states provide clear guidance
- [ ] Loading states prevent user confusion
- [ ] Accessibility features work correctly
- [ ] Dynamic Type scales appropriately
- [ ] Reduced Motion alternatives function
- [ ] Memory usage stays within limits
- [ ] Network errors handled gracefully
- [ ] Security states enforce properly