import SwiftUI
import CryptoKit

struct ProfileIconGenerator {
    // Generate a unique gradient based on profile ID
    static func generateIcon(for profileId: String, size: CGFloat = 100) -> some View {
        ZStack {
            // Generate deterministic colors from profile ID
            let colors = generateColors(from: profileId)
            
            // Background gradient
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glass overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Pattern overlay based on hash
            GeometryReader { geometry in
                Path { path in
                    let pattern = generatePattern(from: profileId, in: geometry.size)
                    path.addLines(pattern)
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
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
    
    // MARK: - Private Helpers
    
    private static func generateColors(from id: String) -> [Color] {
        // Create hash from profile ID
        let data = Data(id.utf8)
        let hash = SHA256.hash(data: data)
        let hashBytes = Array(hash)
        
        // Generate colors in black/silver/gray palette
        let hue1 = Double(hashBytes[0]) / 255.0 * 0.1 // Keep hue low for grayscale
        let saturation1 = Double(hashBytes[1]) / 255.0 * 0.3 // Low saturation for silver effect
        let brightness1 = Double(hashBytes[2]) / 255.0 * 0.4 + 0.3 // Mid to dark range
        
        let hue2 = Double(hashBytes[3]) / 255.0 * 0.1
        let saturation2 = Double(hashBytes[4]) / 255.0 * 0.2
        let brightness2 = Double(hashBytes[5]) / 255.0 * 0.3 + 0.6 // Lighter range
        
        return [
            Color(hue: hue1, saturation: saturation1, brightness: brightness1),
            Color(hue: hue2, saturation: saturation2, brightness: brightness2)
        ]
    }
    
    private static func generatePattern(from id: String, in size: CGSize) -> [CGPoint] {
        // Create hash for pattern generation
        let data = Data(id.utf8)
        let hash = SHA256.hash(data: data)
        let hashBytes = Array(hash)
        
        var points: [CGPoint] = []
        
        // Generate geometric pattern based on hash
        let patternType = Int(hashBytes[6]) % 3
        
        switch patternType {
        case 0: // Diagonal lines
            let lineCount = Int(hashBytes[7]) % 3 + 2
            for i in 0..<lineCount {
                let offset = CGFloat(i) * size.width / CGFloat(lineCount)
                points.append(CGPoint(x: offset, y: 0))
                points.append(CGPoint(x: size.width, y: size.height - offset))
            }
        case 1: // Hexagon pattern
            let centerX = size.width / 2
            let centerY = size.height / 2
            let radius = size.width * 0.3
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let x = centerX + radius * cos(angle)
                let y = centerY + radius * sin(angle)
                points.append(CGPoint(x: x, y: y))
            }
            points.append(points[0]) // Close the hexagon
        default: // Circle pattern
            let circles = Int(hashBytes[8]) % 2 + 1
            for i in 0..<circles {
                let radius = size.width * CGFloat(0.2 + Double(i) * 0.15)
                let centerX = size.width / 2
                let centerY = size.height / 2
                
                // Add circle points
                for j in 0...8 {
                    let angle = CGFloat(j) * .pi / 4
                    let x = centerX + radius * cos(angle)
                    let y = centerY + radius * sin(angle)
                    points.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        return points
    }
}

// Preview
struct ProfileIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ProfileIconGenerator.generateIcon(for: "profile1")
            ProfileIconGenerator.generateIcon(for: "profile2")
            ProfileIconGenerator.emojiIcon("🎮")
            ProfileIconGenerator.generateIcon(for: "profile3", size: 60)
        }
        .padding()
        .background(Color.black)
    }
}