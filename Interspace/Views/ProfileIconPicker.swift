import SwiftUI
import PhotosUI

struct ProfileIconPicker: View {
    @Binding var selectedIcon: ProfileIconType
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var selectedEmoji = "😊"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: Image?
    
    enum ProfileIconType {
        case generated
        case emoji(String)
        case custom(Image)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview
                VStack(spacing: 16) {
                    iconPreview
                        .padding(.top, 20)
                    
                    Text("Choose Profile Icon")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.label)
                }
                .padding(.bottom, 20)
                
                // Tab Selection
                Picker("Icon Type", selection: $selectedTab) {
                    Text("Generated").tag(0)
                    Text("Emoji").tag(1)
                    Text("Photo").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Content based on tab
                Group {
                    switch selectedTab {
                    case 0:
                        generatedIconsView
                    case 1:
                        emojiPickerView
                    case 2:
                        photoPickerView
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Profile Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        handleSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Icon Preview
    @ViewBuilder
    private var iconPreview: some View {
        ZStack {
            Circle()
                .fill(Color.systemGray6)
                .frame(width: 120, height: 120)
            
            switch selectedTab {
            case 0:
                ProfileIconGenerator.generateIcon(for: UUID().uuidString, size: 120)
            case 1:
                Text(selectedEmoji)
                    .font(.system(size: 60))
            case 2:
                if let selectedImage {
                    selectedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.systemGray3)
                }
            default:
                EmptyView()
            }
        }
        .overlay(
            Circle()
                .stroke(Color.systemGray4, lineWidth: 1)
        )
    }
    
    // MARK: - Generated Icons View
    private var generatedIconsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Unique geometric patterns")
                    .font(.footnote)
                    .foregroundColor(.secondaryLabel)
                    .padding(.horizontal, 20)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(0..<9) { index in
                        ProfileIconGenerator.generateIcon(
                            for: "profile_\(index)",
                            size: 80
                        )
                        .onTapGesture {
                            selectedIcon = .generated
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Emoji Picker View
    private var emojiPickerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose an emoji")
                    .font(.footnote)
                    .foregroundColor(.secondaryLabel)
                    .padding(.horizontal, 20)
                
                // Popular emojis grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                    ForEach(popularEmojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 36))
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedEmoji == emoji ? Color.systemBlue.opacity(0.2) : Color.systemGray6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedEmoji == emoji ? Color.systemBlue : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedEmoji = emoji
                            }
                    }
                }
                .padding(.horizontal, 20)
                
                // System emoji keyboard button
                Button(action: {
                    // This would open system emoji keyboard in a real implementation
                }) {
                    HStack {
                        Image(systemName: "face.smiling")
                        Text("Open Emoji Keyboard")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.systemGray6)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Photo Picker View
    private var photoPickerView: some View {
        VStack(spacing: 20) {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.systemBlue)
                    
                    Text("Choose from Library")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.systemBlue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.systemGray6)
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = Image(uiImage: uiImage)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Methods
    private func handleSave() {
        switch selectedTab {
        case 0:
            selectedIcon = .generated
        case 1:
            selectedIcon = .emoji(selectedEmoji)
        case 2:
            if let image = selectedImage {
                selectedIcon = .custom(image)
            }
        default:
            break
        }
    }
    
    private let popularEmojis = [
        "😊", "🎮", "💼", "🎨", "🚀", "💎",
        "🌟", "🔥", "💰", "📈", "🏆", "⚡️",
        "🌈", "🎯", "💡", "🎸", "📱", "🏠",
        "✨", "🌊", "🎬", "📚", "🏃", "🍕"
    ]
}

// Type alias to match ProfileHeaderView
typealias ProfileIconType = ProfileIconPicker.ProfileIconType

// MARK: - Preview
struct ProfileIconPicker_Previews: PreviewProvider {
    static var previews: some View {
        ProfileIconPicker(selectedIcon: .constant(.generated))
    }
}