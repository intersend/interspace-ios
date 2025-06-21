# Wallet Page Design Patterns

## Overview
This document reverse-engineers Apple Wallet's interface design and financial app patterns, analyzing every interaction, animation, and visual element with military-grade precision for iOS 26 Liquid Glass implementation.

## Apple Wallet Interface Analysis

### Card Stack Architecture
```
Physical Dimensions:
- Card width: 358pt (edge-to-edge minus 16pt margins)
- Card height: 224pt (credit card aspect ratio 1.6:1)
- Stack offset: 8pt vertical between cards
- Corner radius: 16pt continuous curve
- Maximum visible cards: 3.5 (encourages scroll discovery)

Shadow System:
- Primary shadow: black(0.25), radius: 20pt, offset: (0, 10pt)
- Contact shadow: black(0.1), radius: 2pt, offset: (0, 1pt)
- Stack depth: Decreasing opacity by 0.1 per layer
```

### Card Layer Composition
```
Layer Stack (bottom to top):
1. Background gradient
   - Type: Linear, 135° angle
   - Colors: Bank/provider specific
   - Opacity: 0.95

2. Glass material base
   - Material: .ultraThinMaterial
   - Opacity: 0.7
   - Blend mode: Normal

3. Lensing distortion layer
   - Real-time background sampling
   - Distortion intensity: 0.15
   - Update frequency: 60fps during motion

4. Content container
   - Padding: 24pt all sides
   - Layout: Provider logo + balance + details

5. Specular highlight
   - Gradient: white(0.4) to clear
   - Height: 1pt
   - Position: Top edge only

6. Border definition
   - Stroke: white(0.2), 0.5pt
   - Inner glow: white(0.1), 2pt blur
```

## Card Interaction Patterns

### Selection and Navigation
```
Tap Response:
1. Scale down to 0.98 (0.1s)
2. Haptic: Light impact
3. Navigation transition begins
4. Card expands to full screen

Pan Gesture Recognition:
- Minimum distance: 10pt
- Velocity threshold: 100pt/s
- Direction lock: Vertical after 20pt
- Resistance: Rubber band physics
```

### Stack Management
```
Card Ordering:
- Active card: Top position, full opacity
- Secondary: -8pt Y offset, 0.9 opacity
- Tertiary: -16pt Y offset, 0.8 opacity
- Hidden: Scale 0.95, 0.7 opacity

Reordering Animation:
- Drag threshold: 15pt
- Lift scale: 1.05
- Shadow expansion: 30pt radius
- Other cards: Smooth position updates
- Drop animation: Spring(0.4, 0.8)
```

### Card State Transitions
```
Active State:
- Full size and opacity
- Animated gradient background
- Live balance updates
- Interactive elements enabled

Inactive State:
- Reduced scale (0.95)
- Lower opacity (0.8)
- Static gradient
- Interactions disabled

Loading State:
- Shimmer overlay animation
- Balance placeholder: "••••••"
- Network indicator: Pulsing dot
```

## Financial Interface Standards

### Balance Display
```
Primary Balance:
- Font: SF Pro Display Medium, 36pt
- Color: White (always high contrast)
- Position: Vertically centered
- Animation: Number morphing over 0.8s

Secondary Currency:
- Font: SF Pro Text Regular, 18pt
- Color: White(0.8)
- Position: Below primary, 4pt spacing
- Format: Localized currency

Precision Handling:
- Cryptocurrency: 6 decimal places maximum
- Fiat currency: 2 decimal places
- Large numbers: Abbreviated (1.2M, 3.4B)
- Zero balance: "0" not "0.00"
```

### Security Patterns
```
Sensitive Data Masking:
- Pattern: "••••••" for hidden balances
- Reveal animation: Fade transition 0.3s
- Auto-hide timeout: 30 seconds
- Biometric gate: Face ID/Touch ID required

Transaction Amounts:
- Outgoing: Red text, minus prefix
- Incoming: Green text, plus prefix
- Pending: Orange text, clock icon
- Failed: Gray text with warning icon
```

### Network Status Indicators
```
Connected State:
- Indicator: Green dot, 8pt diameter
- Position: Top-right, 16pt margins
- Glow effect: Green(0.3), 4pt radius

Syncing State:
- Indicator: Pulsing orange dot
- Animation: Scale 1.0 to 1.2, 1s cycle
- Accessibility: "Syncing" announcement

Error State:
- Indicator: Red dot with warning icon
- Haptic: Error feedback on appearance
- Tap gesture: Show error details
```

## Transaction List Design

### Cell Structure
```
Dimensions:
- Height: 72pt minimum
- Padding: 16pt horizontal, 12pt vertical
- Separator: 0.5pt, inset 60pt from leading

Content Layout:
- Icon container: 40pt × 40pt, leading aligned
- Text container: 60pt leading offset
- Amount container: Trailing aligned
- Time stamp: Below amount, right aligned

Background States:
- Default: Clear
- Pressed: White(0.05)
- Selected: Blue(0.1)
```

### Transaction Icons
```
Icon Specifications:
- Size: 24pt SF Symbol or custom
- Background: 40pt circle with provider color(0.15)
- Colors: Semantic mapping to transaction type

Type Mapping:
- Send: Arrow up-right, red background
- Receive: Arrow down-left, green background  
- Swap: Two curved arrows, blue background
- Stake: Star in circle, purple background
- Contract: Document, orange background
```

### Amount Formatting
```
Typography:
- Font: SF Pro Display Medium, 17pt
- Alignment: Right
- Color: Based on transaction type

Precision Rules:
- Tokens: Up to 6 decimals, trailing zeros removed
- Fiat: Exactly 2 decimals, always shown
- Large amounts: Scientific notation for >1B
- Negative amounts: Minus sign, not parentheses
```

## Send/Receive Flow Patterns

### Input Field Design
```
Recipient Address:
- Height: 56pt
- Font: SF Mono Regular, 16pt
- Background: .quaternarySystemFill
- Border: 1pt, tertiary label color
- Corner radius: 12pt
- Validation: Real-time with checkmark/x

Amount Input:
- Height: 80pt
- Font: SF Pro Display Light, 42pt
- Text alignment: Center
- Background: Transparent
- Cursor: Blue, 2pt width
- Placeholder: "0"
```

### Action Sheets
```
Send Confirmation:
- Style: .formSheet presentation
- Background: .systemGroupedBackground
- Header: Transaction summary card
- Details: From/to addresses, fees, total

Button Layout:
- Primary: "Slide to Send", 50pt height
- Secondary: "Cancel", 44pt height
- Spacing: 16pt between buttons
- Corners: 25pt radius for slide button
```

### Progress States
```
Sending Animation:
1. Button morphs to progress bar
2. Network submission indicator
3. Blockchain confirmation tracking
4. Success checkmark animation
5. Auto-dismiss after 2 seconds

Error Handling:
- Shake animation on failure
- Red border around invalid fields
- Error message below input
- Retry button prominently displayed
```

## Biometric Authentication Overlays

### Face ID Interface
```
Modal Presentation:
- Style: .overFullScreen
- Background: Black(0.7) blur
- Center card: 280pt × 200pt
- Animation: Scale up from 0.8

Visual Elements:
- Face ID glyph: 64pt, system blue
- Title: "Authenticate Transaction"
- Subtitle: Transaction amount
- Animation: Gentle pulsing on scan
```

### Touch ID Interface
```
System Alert:
- Title: App name + "Transaction"
- Message: Amount and recipient
- Buttons: "Cancel" and "Use Passcode"
- Haptic: Medium impact on presentation
```

### Authentication States
```
Scanning:
- Continuous pulse animation
- Blue tint on Face ID glyph
- "Look at iPhone" instruction

Success:
- Checkmark animation
- Green tint transition
- Success haptic pattern
- Auto-dismiss: 0.5s delay

Failure:
- Red shake animation
- Error haptic pattern
- Retry instruction
- Fallback to passcode after 3 attempts
```

## Apple Card Specific Patterns

### Card Design Language
```
Visual Hierarchy:
- Apple logo: Top-left, 24pt
- Cardholder name: Bottom-left, 14pt medium
- Card number: Hidden by default
- Chip: Visual element only, not functional

Color System:
- Background: White gradient to light gray
- Text: Black for maximum contrast
- Accent: None (minimal design)
- Material: Titanium visual texture
```

### Spending Visualization
```
Chart Component:
- Type: Horizontal bar chart
- Height: 200pt
- Animation: Grow from left, 1s duration
- Colors: Category-based semantic colors

Category Icons:
- Food: Fork and knife
- Shopping: Bag
- Entertainment: TV
- Transportation: Car
- Each 20pt SF Symbol in colored circle
```

### Transaction Categorization
```
Automatic Classification:
- Merchant name parsing
- MCC code interpretation
- Location-based inference
- User correction learning

Visual Representation:
- Color coding by category
- Icon mapping to merchant type
- Spending limit indicators
- Budget progress bars
```

## Performance Optimization

### Rendering Strategy
```
Card Stack Optimization:
- Visible cards only: Full render
- Off-screen cards: Static snapshots
- Background cards: Reduced detail
- Memory limit: 100MB for all cards

Animation Performance:
- Core Animation layers for glass effects
- Metal shaders for real-time distortion
- Background queue for heavy calculations
- Main thread: UI updates only
```

### Memory Management
```
Cache Strategy:
- Transaction cache: 1000 items maximum
- Image cache: 50MB allocation
- Graph data: 30 days rolling window
- Purge strategy: LRU with memory pressure

Background Tasks:
- Balance updates: Every 30 seconds
- Transaction sync: Every 2 minutes
- Exchange rates: Every 5 minutes
- Background app refresh: Enabled
```

## Accessibility Implementation

### VoiceOver Support
```
Card Description:
"Ethereum wallet, balance 1.5 ETH, $3,000 US dollars"

Transaction Cell:
"Received 0.1 ETH from DeFi protocol, 2 hours ago"

Button Actions:
"Send button", "Receive button", "Transaction history"

Security Elements:
"Face ID authentication required for transaction"
```

### Dynamic Type Scaling
```
Text Scaling:
- Minimum: .xSmall (11pt base)
- Maximum: .accessibility5 (53pt base)
- Balance: Scales with display font
- Addresses: Monospace, no scaling
- Icons: Fixed size for recognition
```

### Reduced Motion
```
Alternative Animations:
- Card transitions: Fade instead of scale
- Progress indicators: Static bars
- Success feedback: Color change only
- Loading states: Opacity changes
```

## Security UI Standards

### Data Protection Levels
```
Level 1 (Public):
- Wallet names and icons
- Network status
- Transaction count

Level 2 (Biometric):
- Account balances
- Transaction amounts
- Recipient addresses

Level 3 (Passcode):
- Private keys
- Seed phrases
- Authentication tokens
```

### Privacy Modes
```
Screenshot Protection:
- Balance hiding: Automatic
- Private data blur: System level
- Screen recording: Blocked

App Background:
- Balance masking: Immediate
- Blur overlay: System provided
- Resume authentication: Required
```

## Testing Requirements

### Performance Benchmarks
```
Targets:
- Card animation: 60fps sustained
- List scrolling: 60fps minimum
- Balance updates: <500ms
- Transaction send: <2s to network
- Biometric auth: <3s typical

Memory Limits:
- Total allocation: 200MB maximum
- Peak usage: 250MB allowed
- Leak detection: Zero tolerance
- Cache efficiency: 95% hit rate
```

### Security Validation
```
Penetration Testing:
- Biometric bypass attempts
- Memory dump analysis
- Network traffic inspection
- Keychain security verification

User Testing:
- Authentication flow usability
- Error message clarity
- Accessibility compliance
- Cross-device consistency
```

## Quality Checklist

- [ ] Card stack animations maintain 60fps
- [ ] Balance updates reflect in real-time
- [ ] Biometric authentication works reliably
- [ ] Transaction list scrolls smoothly
- [ ] Glass effects render without artifacts
- [ ] Security overlays prevent data exposure
- [ ] Accessibility features fully functional
- [ ] Memory usage within defined limits
- [ ] Network errors handled gracefully
- [ ] All financial data formatted correctly
- [ ] Cross-platform consistency maintained
- [ ] Recovery flows tested and verified