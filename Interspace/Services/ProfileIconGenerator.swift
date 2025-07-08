import SwiftUI
import CryptoKit

struct ProfileIconGenerator {
    // Generate a unique gradient based on profile ID
    static func generateIcon(for profileId: String, size: CGFloat = 100) -> some View {
        let colorScheme = generateColorScheme(from: profileId)
        return ZStack {
            // Black/silver base gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(white: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Vibrant color accent overlay
            RadialGradient(
                colors: [
                    colorScheme.primary.opacity(0.8),
                    colorScheme.secondary.opacity(0.4),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.7
            )
            
            // Silver metallic sheen
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.clear,
                    Color.white.opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Abstract pattern overlay
            GeometryReader { geometry in
                generateAbstractPattern(from: profileId, colorScheme: colorScheme, in: geometry.size)
            }
            
            // Glass overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: colorScheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    // Generate emoji-based icon
    static func emojiIcon(_ emoji: String, size: CGFloat = 100) -> some View {
        ZStack {
            Circle()
                .fill(Color.systemGray5)
            
            Text(emoji)
                .font(.system(size: size * 0.5))
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Generate custom image icon
    static func imageIcon(_ image: Image, size: CGFloat = 100) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Private Types
    
    struct ColorScheme {
        let primary: Color
        let secondary: Color
        let accent: Color
    }
    
    // MARK: - Private Helpers
    
    private static func generateColorScheme(from id: String) -> ColorScheme {
        // Create hash from profile ID (can be session address)
        let data = Data(id.utf8)
        let hash = SHA256.hash(data: data)
        let hashBytes = Array(hash)
        
        // Generate vibrant colors with high saturation
        let primaryHue = Double(hashBytes[0]) / 255.0
        let secondaryHue = (primaryHue + Double(hashBytes[1]) / 510.0).truncatingRemainder(dividingBy: 1.0)
        let accentHue = (primaryHue + 0.5).truncatingRemainder(dividingBy: 1.0)
        
        // High saturation for vibrant colors
        let primarySaturation = 0.7 + Double(hashBytes[2]) / 1275.0 // 0.7-0.9
        let secondarySaturation = 0.6 + Double(hashBytes[3]) / 1275.0 // 0.6-0.8
        
        // Bright values
        let primaryBrightness = 0.8 + Double(hashBytes[4]) / 1275.0 // 0.8-1.0
        let secondaryBrightness = 0.7 + Double(hashBytes[5]) / 1275.0 // 0.7-0.9
        
        return ColorScheme(
            primary: Color(hue: primaryHue, saturation: primarySaturation, brightness: primaryBrightness),
            secondary: Color(hue: secondaryHue, saturation: secondarySaturation, brightness: secondaryBrightness),
            accent: Color(hue: accentHue, saturation: 0.8, brightness: 0.9)
        )
    }
    
    private static func generateAbstractPattern(from id: String, colorScheme: ColorScheme, in size: CGSize) -> some View {
        // Create hash for pattern generation
        let data = Data(id.utf8)
        let hash = SHA256.hash(data: data)
        let hashBytes = Array(hash)
        
        // Generate multiple pattern layers
        let patternType = Int(hashBytes[6]) % 6
        
        return ZStack {
            switch patternType {
            case 0: // Flowing waves
                WavePattern(id: id, colorScheme: colorScheme, size: size)
            case 1: // Geometric triangles
                TrianglePattern(id: id, colorScheme: colorScheme, size: size)
            case 2: // Spiral pattern
                SpiralPattern(id: id, colorScheme: colorScheme, size: size)
            case 3: // Abstract dots
                DotPattern(id: id, colorScheme: colorScheme, size: size)
            case 4: // Tessellation
                TessellationPattern(id: id, colorScheme: colorScheme, size: size)
            default: // Mixed geometric
                MixedGeometricPattern(id: id, colorScheme: colorScheme, size: size)
            }
        }
    }
}

// MARK: - Pattern Views

private struct WavePattern: View {
    let id: String
    let colorScheme: ProfileIconGenerator.ColorScheme
    let size: CGSize
    
    var body: some View {
        Path { path in
            let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
            let waveCount = Int(hashBytes[7]) % 3 + 2
            
            for i in 0..<waveCount {
                let yOffset = size.height * CGFloat(i) / CGFloat(waveCount)
                let amplitude = size.height * 0.1
                let frequency = CGFloat(hashBytes[8 + i] % 3 + 2)
                
                path.move(to: CGPoint(x: 0, y: yOffset))
                
                for x in stride(from: 0, to: size.width, by: 2) {
                    let y = yOffset + amplitude * sin(x / size.width * .pi * frequency)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(
            LinearGradient(
                colors: [colorScheme.primary.opacity(0.3), colorScheme.secondary.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            lineWidth: 2
        )
    }
}

private struct TrianglePattern: View {
    let id: String
    let colorScheme: ProfileIconGenerator.ColorScheme
    let size: CGSize
    
    var body: some View {
        Path { path in
            let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
            let triangleCount = Int(hashBytes[7]) % 3 + 2
            
            for i in 0..<triangleCount {
                let scale = CGFloat(0.3 + Double(i) * 0.2)
                let rotation = CGFloat(hashBytes[8 + i]) / 255.0 * .pi * 2
                let centerX = size.width * (0.3 + CGFloat(hashBytes[9 + i]) / 510.0)
                let centerY = size.height * (0.3 + CGFloat(hashBytes[10 + i]) / 510.0)
                
                let p1 = CGPoint(x: centerX, y: centerY - size.height * scale)
                let p2 = CGPoint(x: centerX - size.width * scale * 0.5, y: centerY + size.height * scale * 0.5)
                let p3 = CGPoint(x: centerX + size.width * scale * 0.5, y: centerY + size.height * scale * 0.5)
                
                path.move(to: p1)
                path.addLine(to: p2)
                path.addLine(to: p3)
                path.closeSubpath()
            }
        }
        .fill(colorScheme.accent.opacity(0.2))
        .overlay(
            Path { path in
                let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
                let triangleCount = Int(hashBytes[7]) % 3 + 2
                
                for i in 0..<triangleCount {
                    let scale = CGFloat(0.3 + Double(i) * 0.2)
                    let centerX = size.width * (0.3 + CGFloat(hashBytes[9 + i]) / 510.0)
                    let centerY = size.height * (0.3 + CGFloat(hashBytes[10 + i]) / 510.0)
                    
                    let p1 = CGPoint(x: centerX, y: centerY - size.height * scale)
                    let p2 = CGPoint(x: centerX - size.width * scale * 0.5, y: centerY + size.height * scale * 0.5)
                    let p3 = CGPoint(x: centerX + size.width * scale * 0.5, y: centerY + size.height * scale * 0.5)
                    
                    path.move(to: p1)
                    path.addLine(to: p2)
                    path.addLine(to: p3)
                    path.closeSubpath()
                }
            }
            .stroke(colorScheme.primary.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct SpiralPattern: View {
    let id: String
    let colorScheme: ProfileIconGenerator.ColorScheme
    let size: CGSize
    
    var body: some View {
        Path { path in
            let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
            let spiralTurns = CGFloat(hashBytes[7] % 3 + 2)
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            var angle: CGFloat = 0
            var radius: CGFloat = 0
            
            path.move(to: CGPoint(x: centerX, y: centerY))
            
            while radius < size.width * 0.4 {
                angle += 0.1
                radius = angle * 2
                
                let x = centerX + radius * cos(angle)
                let y = centerY + radius * sin(angle)
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        .stroke(
            LinearGradient(
                colors: [colorScheme.primary.opacity(0.5), colorScheme.secondary.opacity(0.2)],
                startPoint: .center,
                endPoint: .bottomTrailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
    }
}

private struct DotPattern: View {
    let id: String
    let colorScheme: ProfileIconGenerator.ColorScheme
    let size: CGSize
    
    var body: some View {
        ZStack {
            let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
            let dotCount = Int(hashBytes[7]) % 15 + 10
            
            ForEach(0..<dotCount, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? colorScheme.primary.opacity(0.3) : colorScheme.secondary.opacity(0.3))
                    .frame(
                        width: CGFloat(hashBytes[8 + i % 20] % 20 + 5),
                        height: CGFloat(hashBytes[8 + i % 20] % 20 + 5)
                    )
                    .position(
                        x: CGFloat(hashBytes[10 + i * 2] % 80 + 10) / 100 * size.width,
                        y: CGFloat(hashBytes[11 + i * 2] % 80 + 10) / 100 * size.height
                    )
            }
        }
    }
}

private struct TessellationPattern: View {
    let id: String
    let colorScheme: ProfileIconGenerator.ColorScheme
    let size: CGSize
    
    var body: some View {
        Path { path in
            let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
            let gridSize = CGFloat(hashBytes[7] % 3 + 4)
            let cellSize = size.width / gridSize
            
            for row in 0..<Int(gridSize) {
                for col in 0..<Int(gridSize) {
                    let x = CGFloat(col) * cellSize
                    let y = CGFloat(row) * cellSize
                    
                    if (row + col) % 2 == 0 {
                        // Diamond shape
                        path.move(to: CGPoint(x: x + cellSize / 2, y: y))
                        path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize / 2))
                        path.addLine(to: CGPoint(x: x + cellSize / 2, y: y + cellSize))
                        path.addLine(to: CGPoint(x: x, y: y + cellSize / 2))
                        path.closeSubpath()
                    }
                }
            }
        }
        .fill(colorScheme.accent.opacity(0.2))
        .overlay(
            Path { path in
                let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
                let gridSize = CGFloat(hashBytes[7] % 3 + 4)
                let cellSize = size.width / gridSize
                
                for row in 0..<Int(gridSize) {
                    for col in 0..<Int(gridSize) {
                        let x = CGFloat(col) * cellSize
                        let y = CGFloat(row) * cellSize
                        
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + cellSize, y: y))
                        path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize))
                        path.addLine(to: CGPoint(x: x, y: y + cellSize))
                        path.closeSubpath()
                    }
                }
            }
            .stroke(colorScheme.primary.opacity(0.3), lineWidth: 0.5)
        )
    }
}

private struct MixedGeometricPattern: View {
    let id: String
    let colorScheme: ProfileIconGenerator.ColorScheme
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Combine multiple simple shapes
            let hashBytes = Array(SHA256.hash(data: Data(id.utf8)))
            
            // Large background circle
            Circle()
                .fill(colorScheme.secondary.opacity(0.1))
                .frame(width: size.width * 0.7, height: size.height * 0.7)
                .offset(
                    x: CGFloat(Int(hashBytes[8]) - 128) / 256 * size.width * 0.2,
                    y: CGFloat(Int(hashBytes[9]) - 128) / 256 * size.height * 0.2
                )
            
            // Overlapping rectangles
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: size.width * 0.1)
                    .fill(i == 0 ? colorScheme.primary.opacity(0.2) : colorScheme.accent.opacity(0.15))
                    .frame(
                        width: size.width * CGFloat(0.3 + Double(hashBytes[10 + i]) / 500),
                        height: size.height * CGFloat(0.3 + Double(hashBytes[13 + i]) / 500)
                    )
                    .rotationEffect(.degrees(Double(hashBytes[16 + i]) / 255 * 360))
                    .offset(
                        x: CGFloat(Int(hashBytes[19 + i]) - 128) / 256 * size.width * 0.3,
                        y: CGFloat(Int(hashBytes[22 + i]) - 128) / 256 * size.height * 0.3
                    )
            }
        }
    }
}

// Preview
struct ProfileIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ProfileIconGenerator.generateIcon(for: "0x1234567890abcdef")
                ProfileIconGenerator.generateIcon(for: "0xfedcba0987654321")
            }
            HStack(spacing: 20) {
                ProfileIconGenerator.generateIcon(for: "profile3@example.com")
                ProfileIconGenerator.generateIcon(for: "unique-user-id-456")
            }
            HStack(spacing: 20) {
                ProfileIconGenerator.emojiIcon("🎮", size: 80)
                ProfileIconGenerator.generateIcon(for: "test-profile", size: 80)
            }
        }
        .padding()
        .background(Color.black)
    }
}
