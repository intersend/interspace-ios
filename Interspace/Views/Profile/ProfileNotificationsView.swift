import SwiftUI

struct ProfileNotificationsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Notification preferences
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true
    @AppStorage("transactionNotifications") private var transactionNotifications = true
    @AppStorage("accountActivityNotifications") private var accountActivityNotifications = true
    @AppStorage("marketingNotifications") private var marketingNotifications = false
    @AppStorage("securityAlerts") private var securityAlerts = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Text("Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color(white: 0.15))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            List {
                    // Main Push Notifications Toggle
                    Section {
                        Toggle(isOn: $pushNotificationsEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                    .frame(width: 36, height: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Push Notifications")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Text("Allow Interspace to send you notifications")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .listRowBackground(Color(white: 0.1))
                        .onChange(of: pushNotificationsEnabled) { newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                    }
                    
                    // Notification Types Section
                    if pushNotificationsEnabled {
                        Section(header: Text("NOTIFICATION TYPES")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)) {
                            
                            // Transactions
                            Toggle(isOn: $transactionNotifications) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.left.arrow.right.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Transactions")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        
                                        Text("Get notified about incoming and outgoing transactions")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .listRowBackground(Color(white: 0.1))
                            
                            // Account Activity
                            Toggle(isOn: $accountActivityNotifications) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.badge.clock")
                                        .font(.system(size: 20))
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Account Activity")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        
                                        Text("New sign-ins and profile changes")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .listRowBackground(Color(white: 0.1))
                            
                            // Security Alerts
                            Toggle(isOn: $securityAlerts) {
                                HStack(spacing: 12) {
                                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Security Alerts")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        
                                        Text("Important security updates and warnings")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .listRowBackground(Color(white: 0.1))
                            
                            // Marketing & Updates
                            Toggle(isOn: $marketingNotifications) {
                                HStack(spacing: 12) {
                                    Image(systemName: "megaphone")
                                        .font(.system(size: 20))
                                        .foregroundColor(.purple)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Updates & Features")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        
                                        Text("New features and product updates")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .listRowBackground(Color(white: 0.1))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Notification Settings Info
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                Text("Notification Settings")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("You can manage system notification settings for Interspace in your device Settings app.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Button(action: {
                                // Open Settings app
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Open Settings")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 12)
                        .listRowBackground(Color(white: 0.05))
                    }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .animation(.easeInOut, value: pushNotificationsEnabled)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Methods
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    HapticManager.notification(.success)
                } else {
                    // Permission denied, revert toggle
                    pushNotificationsEnabled = false
                    HapticManager.notification(.error)
                }
            }
        }
    }
}

// MARK: - Preview

struct ProfileNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileNotificationsView()
            .preferredColorScheme(.dark)
    }
}