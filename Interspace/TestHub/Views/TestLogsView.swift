import SwiftUI

struct TestLogsView: View {
    @State private var logs: [TestLogger.LogEntry] = []
    @State private var selectedCategory: String = "All"
    @State private var selectedLevel: TestLogger.LogLevel?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    private var categories: [String] {
        var cats = Set<String>()
        cats.insert("All")
        logs.forEach { cats.insert($0.category) }
        return Array(cats).sorted()
    }
    
    private var filteredLogs: [TestLogger.LogEntry] {
        var filtered = logs
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by level
        if let level = selectedLevel {
            filtered = filtered.filter { $0.level == level }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                filterSection
                
                // Search
                searchBar
                
                // Logs
                if filteredLogs.isEmpty {
                    emptyState
                } else {
                    logsList
                }
            }
            .navigationTitle("Test Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            exportLogs()
                        } label: {
                            Label("Export Logs", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            clearLogs()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadLogs()
            }
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Category filter
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    HStack {
                        Text("Category: \(selectedCategory)")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                
                // Level filters
                ForEach(TestLogger.LogLevel.allCases, id: \.self) { level in
                    Button {
                        if selectedLevel == level {
                            selectedLevel = nil
                        } else {
                            selectedLevel = level
                        }
                    } label: {
                        Text(level.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedLevel == level ? levelColor(level) : Color.gray.opacity(0.2))
                            .foregroundColor(selectedLevel == level ? .white : .primary)
                            .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Logs Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var logsList: some View {
        List(filteredLogs, id: \.timestamp) { entry in
            LogEntryRow(entry: entry)
        }
        .listStyle(.plain)
    }
    
    private func loadLogs() {
        logs = TestLogger.shared.getAllLogs()
    }
    
    private func clearLogs() {
        TestLogger.shared.clearLogs()
        logs = []
    }
    
    private func exportLogs() {
        // Implementation would export logs
        if let data = TestLogger.shared.exportLogsAsText().data(using: .utf8) {
            // Share logs
        }
    }
    
    private func levelColor(_ level: TestLogger.LogLevel) -> Color {
        switch level {
        case .debug: return .purple
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}

extension TestLogger.LogLevel: CaseIterable {
    static var allCases: [TestLogger.LogLevel] = [.debug, .info, .warning, .error, .success]
}

struct LogEntryRow: View {
    let entry: TestLogger.LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Level indicator
                Circle()
                    .fill(levelColor(entry.level))
                    .frame(width: 8, height: 8)
                
                // Category
                Text(entry.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Timestamp
                Text(formatTime(entry.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Message
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(3)
            
            // Metadata
            if let metadata = entry.metadata, !metadata.isEmpty {
                Text(metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func levelColor(_ level: TestLogger.LogLevel) -> Color {
        switch level {
        case .debug: return .purple
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}