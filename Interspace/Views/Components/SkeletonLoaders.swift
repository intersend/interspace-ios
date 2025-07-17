import SwiftUI

// MARK: - Skeleton Modifier

struct SkeletonModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let animation = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemGray5),
                        Color(UIColor.systemGray4),
                        Color(UIColor.systemGray5)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200 - 100)
                .animation(animation, value: phase)
            )
            .onAppear {
                phase = 1
            }
    }
}

extension View {
    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Account Row Skeleton

struct AccountRowSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Icon placeholder
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 32, height: 32)
                .skeleton()
            
            VStack(alignment: .leading, spacing: 4) {
                // Name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 120, height: 16)
                    .skeleton()
                
                // Address/identifier placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 180, height: 12)
                    .skeleton()
            }
            
            Spacer()
            
            // Chevron placeholder
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(UIColor.systemGray5))
                .frame(width: 8, height: 14)
                .skeleton()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Profile Header Skeleton

struct ProfileHeaderSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Profile icon placeholder
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 60, height: 60)
                .skeleton()
            
            VStack(alignment: .leading, spacing: 4) {
                // Name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 100, height: 20)
                    .skeleton()
                
                // Address placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 200, height: 14)
                    .skeleton()
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Section Skeleton

struct SectionSkeleton: View {
    let title: String
    let itemCount: Int
    
    var body: some View {
        Section(header: Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.gray)) {
            ForEach(0..<itemCount, id: \.self) { _ in
                AccountRowSkeleton()
            }
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - Full Profile Skeleton

struct ProfileViewSkeleton: View {
    var body: some View {
        List {
            // Profile Header
            Section {
                ProfileHeaderSkeleton()
                
                // My Profiles row skeleton
                HStack {
                    Image(systemName: "person.2")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Text("My Profiles")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
            
            // Linked Accounts skeleton
            SectionSkeleton(title: "LINKED ACCOUNTS", itemCount: 2)
            
            // Social Accounts skeleton
            SectionSkeleton(title: "SOCIAL ACCOUNTS", itemCount: 2)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .disabled(true) // Disable all interactions
    }
}

// MARK: - Preview

struct SkeletonLoaders_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AccountRowSkeleton()
                .padding()
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Account Row")
            
            ProfileViewSkeleton()
                .preferredColorScheme(.dark)
                .previewDisplayName("Full Profile View")
        }
    }
}