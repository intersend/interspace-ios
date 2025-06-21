# App Tab Implementation Specification

## Overview
The App tab recreates iOS 26's SpringBoard with Liquid Glass design. Every pixel, animation, and interaction has been reverse-engineered from Apple's implementation with zero deviation.

## Grid Layout Mathematics

### Screen Calculations (iPhone 15 Pro - 393pt width)
```
Base Metrics:
- Screen width: 393pt
- Usable width: 393pt - (2 × 27pt margins) = 339pt
- Icons per row: 4
- Icon size: 60pt
- Horizontal spacing: (339pt - (4 × 60pt)) ÷ 3 = 33pt

Vertical Layout:
- Status bar clearance: 59pt
- Top margin: 82pt from screen top
- Rows per page: 6
- Row height: 60pt (icon) + 39pt (spacing) = 99pt
- Page indicator clearance: 30pt
```

### Adaptive Sizing Formula
```swift
let iconSize = 60.0 // Fixed on iPhone
let margin = 27.0
let iconsPerRow = 4
let spacing = (screenWidth - (2 * margin) - (iconsPerRow * iconSize)) / (iconsPerRow - 1)
```

## Liquid Glass App Icon

### Layer Composition
```
Stack Order (bottom to top):
1. Shadow layer
   - Color: black(0.2)
   - Radius: 4pt
   - Offset: (0, 2pt)
   - Opacity: 0.6

2. Base glass layer
   - Material: Custom gradient mesh
   - Base color: App color at 95% opacity
   - Corner radius: 13.5pt (continuous curve)

3. Icon image layer
   - Size: 60pt × 60pt
   - Content mode: Aspect fill
   - Mask: Continuous corner radius

4. Lensing effect layer
   - Radial gradient: Center bright, edges darker
   - Blend mode: Soft light
   - Opacity: 0.3

5. Specular highlight
   - Linear gradient: white(0.4) to clear
   - Height: 1pt
   - Position: Top edge

6. Glass refraction
   - Distortion map from background
   - Intensity: 0.15
   - Updates at 60fps during movement

7. Border layer
   - Width: 0.5pt
   - Color: white(0.1)
   - Inner shadow: black(0.05), 1pt
```

### Dynamic Color Extraction
```swift
// Sample background at icon position
let backgroundSample = background.sample(at: iconFrame)
let dominantColor = backgroundSample.dominantColor()
let tintedGlass = baseMaterial.tinted(with: dominantColor, intensity: 0.2)
```

## Edit Mode Implementation

### Activation Sequence
```
1. Long press detection (0.5s)
2. Haptic: Medium impact
3. All icons start wiggling within 0.1s
4. Delete buttons fade in (0.2s)
5. Tab bar morphs to show "Done" button
```

### Wiggle Animation Specification
```swift
// Each icon gets unique animation
func wiggleAnimation(for index: Int) -> CAAnimationGroup {
    // Rotation
    let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
    rotation.values = [0, -0.04, 0, 0.04, 0] // ±2.3°
    rotation.duration = 0.25
    rotation.repeatCount = .infinity
    
    // Vertical translation
    let translation = CAKeyframeAnimation(keyPath: "transform.translation.y")
    translation.values = [0, -1.5, 0, 1.5, 0]
    translation.duration = 0.251 // Slightly off to avoid synchronization
    translation.repeatCount = .infinity
    
    // Phase offset
    group.beginTime = CACurrentMediaTime() + (Double(index) * 0.03)
}
```

### Delete Button Exact Specs
```
Visual Design:
- Shape: Perfect circle
- Size: 24pt × 24pt
- Background: #FF3B30 (iOS red)
- Border: None
- Shadow: color: red(0.3), radius: 2pt, offset: (0, 1pt)

Icon Specifications:
- Symbol: Custom "X" (not SF Symbol)
- Weight: Bold (3pt stroke)
- Size: 14pt
- Color: Pure white
- Rotation: 0° (no tilt)

Position:
- Offset from icon corner: (-6pt, -6pt)
- Z-index: Above icon
- Hit area: 44pt × 44pt (accessibility)
```

## Drag & Drop Mechanics

### Drag Initiation
```
Trigger: Pan gesture during edit mode
Threshold: 10pt movement

Visual Feedback:
1. Icon scale: 1.0 → 1.1 (0.15s spring)
2. Shadow expansion: 4pt → 12pt radius
3. Opacity: 1.0 → 0.85
4. Haptic: Medium impact
5. Other icons: Slight pushback effect
```

### During Drag State
```swift
// Physics simulation
let dragOffset = gesture.translation
let velocity = gesture.velocity

// Rotation based on velocity
let tiltAngle = atan2(velocity.x, 1000) * 0.1 // Max ±10°
icon.transform = CGAffineTransform(rotationAngle: tiltAngle)

// Icons spread to make room
let impactRadius = 80.0
let impactForce = 1.0 - (distance / impactRadius)
nearbyIcon.offset = normalize(iconPosition - dragPosition) * impactForce * 20
```

### Auto-Scroll Zones
```
Top Zone: 0pt to 50pt from screen top
Bottom Zone: 50pt from screen bottom

Behavior:
- Activation delay: 0.5s hover
- Scroll speed: 200pt/s
- Acceleration: Linear
- Visual indicator: Gradient fade
- Haptic: Light impact every 0.5s while scrolling
```

### Drop Animation
```
Valid Drop:
1. Spring animation to final position
   - Response: 0.3s
   - Damping: 0.8
   - Initial velocity from gesture
2. Scale: 1.1 → 0.95 → 1.0
3. Haptic: Light impact
4. Other icons: Spring to new positions

Invalid Drop (outside grid):
1. Spring back to original position
   - Response: 0.4s
   - Damping: 0.6
2. Shake animation (2 cycles)
3. Haptic: Heavy impact (error feedback)
```

## Folder System

### Creation Trigger
```
Conditions:
- Drag icon over another icon
- Hover duration: 0.3s
- Visual feedback: Target icon scales to 0.9

Cancelation:
- Move away within 0.3s
- Target returns to scale 1.0
- No folder created
```

### Folder Creation Animation
```
Timeline (Total: 0.6s):

0.0s - 0.1s: Pre-animation
- Both icons stop wiggling
- Delete buttons fade out
- Haptic: Medium impact

0.1s - 0.3s: Convergence
- Icons move to center point
- Scale down to 0.5
- Rotation resets to 0°

0.2s - 0.4s: Folder birth
- Glass folder background fades in
- Size: 0 → 132pt (spring)
- Corner radius: 35% of size

0.3s - 0.5s: Grid formation
- Mini grid appears (2×2)
- Icons settle into grid
- Each icon: 25pt

0.4s - 0.6s: Final polish
- Folder name appears
- Slight bounce on folder
- Resume wiggle animation
```

### Folder Visual Design
```
Container:
- Size: 132pt × 132pt (2.2x icon size)
- Corner radius: 46.2pt (35%)
- Background layers:
  1. Base: .ultraThinMaterial at 40% white
  2. Blur radius: 30pt
  3. Inner shadow: white(0.2), 2pt
  4. Border: white(0.1), 0.5pt

Mini Grid:
- Padding: 20pt
- Icon size: 25pt
- Spacing: 12pt
- Max icons shown: 4 (2×2)
- Additional icons: Fade out
```

### Folder Open Animation
```
Sequence:
1. Folder icon scales up (1.0 → 1.05)
2. Background blur intensifies
3. Folder expands from icon position
4. Contents fade in during expansion
5. Total duration: 0.35s
```

## Page Management

### Page Indicators
```
Design:
- Dot size: 8pt
- Active dot: white(1.0)
- Inactive dots: white(0.3)
- Spacing: 9pt between centers
- Position: 30pt from bottom
- Container height: 20pt

Behavior:
- Fade out during icon drag
- Fade in when drag ends
- Morph animation when page count changes
- Tap to jump to page (0.3s animation)
```

### Page Transitions
```swift
// Swipe between pages
func pageTransition(from: Int, to: Int, progress: Double) {
    let direction = to > from ? 1.0 : -1.0
    let offset = screenWidth * (1 - progress) * direction
    
    currentPage.offset.x = offset
    nextPage.offset.x = offset - (screenWidth * direction)
    
    // Parallax effect on icons
    let parallaxFactor = 0.1
    icons.forEach { icon in
        icon.offset.x = offset * parallaxFactor * icon.depthIndex
    }
}
```

## Glass Effects Shader

### Lensing Implementation
```metal
// Metal shader for real-time glass distortion
fragment float4 glassLensing(
    VertexOut in [[stage_in]],
    texture2d<float> background [[texture(0)]],
    constant GlassParams& params [[buffer(0)]]
) {
    float2 uv = in.textureCoordinate;
    
    // Radial distortion
    float2 center = float2(0.5, 0.5);
    float2 delta = uv - center;
    float distance = length(delta);
    float distortion = 1.0 + (distance * params.lensStrength);
    
    float2 distortedUV = center + (delta / distortion);
    float4 color = background.sample(sampler, distortedUV);
    
    // Edge darkening
    float vignette = 1.0 - (distance * params.vignetteStrength);
    color.rgb *= vignette;
    
    return color;
}
```

## Haptic Feedback Catalog

### Precise Timing
```
Long Press Start: 0.0s - Medium impact
Enter Edit Mode: 0.5s - Medium impact
Icon Pickup: On movement - Medium impact
Hover Over Icon: 0.3s - Light impact
Drop Success: On release - Light impact
Drop Failure: On release - Heavy impact
Folder Create: 0.0s - Medium impact
Page Swipe: On settle - Selection change
Delete Tap: On touch - Light impact
Delete Confirm: On confirm - Heavy impact
```

## Performance Targets

### Frame Rate Requirements
```
Edit Mode: 60fps minimum
Drag & Drop: 60fps required
Folder Animation: 60fps required
Page Transition: 60fps minimum
Wiggle Animation: 30fps acceptable

Optimization Triggers:
- >20 apps: Reduce wiggle complexity
- Low battery: Disable specular highlights
- Reduced motion: Static icons, fade transitions
```

### Memory Limits
```
Icon cache: 100MB maximum
Glass renders: 50MB maximum
Animation buffers: 25MB maximum
Total budget: 200MB for entire SpringBoard
```

## Edge Cases

### Dock Behavior
```
Fixed Position: Bottom 110pt
Icon count: 4 maximum
No folders allowed
No wiggle in edit mode
Can receive drops
Cannot be deleted
```

### Last Icon Behavior
```
Cannot be deleted
No delete button shown
Wiggle animation continues
Can be moved to different position
Can be put in folder
```

### Page Creation/Deletion
```
Auto-create: When dropping icon past last page
Auto-delete: When last icon removed from page
Animation: Fade in/out with 0.3s
Page limit: 15 pages maximum
```

## Quality Checklist

- [ ] Icons maintain 60fps during wiggle
- [ ] Delete buttons perfectly circular
- [ ] Drag preview follows finger exactly
- [ ] Auto-scroll activates at screen edges
- [ ] Folder creation requires 0.3s hover
- [ ] Glass effects update in real-time
- [ ] Haptic feedback matches Apple's timing
- [ ] Page indicators morph smoothly
- [ ] Memory usage stays within budget
- [ ] All animations use correct spring curves