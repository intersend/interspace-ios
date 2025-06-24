import SwiftUI

// MARK: - Standard Plus Button
struct StandardPlusButton: View {
    @Binding var showUniversalAddTray: Bool
    let initialSection: AddSection
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            showUniversalAddTray = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(white: 0.15))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Standard Ellipsis Menu
struct StandardEllipsisMenu: View {
    @Binding var showAbout: Bool
    @Binding var showSecurity: Bool
    @Binding var showNotifications: Bool
    @EnvironmentObject var sessionCoordinator: SessionCoordinator
    
    var body: some View {
        Menu {
            Button(action: {
                HapticManager.impact(.light)
                showAbout = true
            }) {
                Label("About", systemImage: "info.circle")
            }
            
            Button(action: {
                HapticManager.impact(.light)
                showSecurity = true
            }) {
                Label("Security", systemImage: "lock.circle")
            }
            
            Button(action: {
                HapticManager.impact(.light)
                showNotifications = true
            }) {
                Label("Notifications", systemImage: "bell.circle")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                HapticManager.impact(.medium)
                Task {
                    await sessionCoordinator.logout()
                }
            }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(white: 0.15))
                )
        }
    }
}

// MARK: - Standard Toolbar Buttons (Combined)
struct StandardToolbarButtons: View {
    @Binding var showUniversalAddTray: Bool
    @Binding var showAbout: Bool
    @Binding var showSecurity: Bool
    @Binding var showNotifications: Bool
    let initialSection: AddSection
    
    var body: some View {
        HStack(spacing: 12) {
            StandardPlusButton(
                showUniversalAddTray: $showUniversalAddTray,
                initialSection: initialSection
            )
            
            StandardEllipsisMenu(
                showAbout: $showAbout,
                showSecurity: $showSecurity,
                showNotifications: $showNotifications
            )
        }
    }
}

// MARK: - Navigation Bar Title Modifier
struct NavigationBarTitleModifier: ViewModifier {
    let title: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
    }
}

extension View {
    func navigationBarTitle(_ title: String) -> some View {
        self.modifier(NavigationBarTitleModifier(title: title))
    }
}