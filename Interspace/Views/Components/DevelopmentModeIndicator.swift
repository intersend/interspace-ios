import SwiftUI

struct DevelopmentModeIndicator: View {
    @AppStorage("isDevelopmentMode") private var isDevelopmentMode = false
    var size: IndicatorSize = .medium
    
    enum IndicatorSize {
        case small
        case medium
        case large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 12
            case .large: return 14
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .large: return EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
            }
        }
    }
    
    var body: some View {
        if isDevelopmentMode {
            Text("DEV")
                .font(.system(size: size.fontSize, weight: .semibold, design: .monospaced))
                .foregroundColor(.black)
                .padding(size.padding)
                .background(
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.8, blue: 0.0)) // Subtle yellow
                )
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    func developmentIndicator(size: DevelopmentModeIndicator.IndicatorSize = .medium) -> some View {
        self.overlay(
            DevelopmentModeIndicator(size: size),
            alignment: .topTrailing
        )
    }
}

// MARK: - Preview

struct DevelopmentModeIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Small size
            HStack {
                Text("Small Size")
                    .font(.headline)
                Spacer()
                DevelopmentModeIndicator(size: .small)
            }
            
            // Medium size
            HStack {
                Text("Medium Size")
                    .font(.headline)
                Spacer()
                DevelopmentModeIndicator(size: .medium)
            }
            
            // Large size
            HStack {
                Text("Large Size")
                    .font(.headline)
                Spacer()
                DevelopmentModeIndicator(size: .large)
            }
            
            Divider()
            
            // Example usage with overlay
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Name")
                    .font(.title2)
                    .bold()
                    .developmentIndicator()
                
                Text("With development indicator overlay")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.systemGray6)
            .cornerRadius(12)
        }
        .padding()
        .onAppear {
            UserDefaults.standard.set(true, forKey: "isDevelopmentMode")
        }
    }
}