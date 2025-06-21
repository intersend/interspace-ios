import SwiftUI

struct TestHubView: View {
    @StateObject private var testRunner = TestRunner()
    @State private var selectedCategory: TestCategory?
    @State private var showingConfiguration = false
    @State private var showingReports = false
    @State private var showingLogs = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Configuration Summary
                    configurationSummary
                    
                    // Test Categories
                    testCategoriesSection
                    
                    // Run Controls
                    runControlsSection
                    
                    // Progress View
                    if testRunner.isRunning {
                        progressSection
                    }
                    
                    // Results Summary
                    if !testRunner.results.isEmpty {
                        resultsSummary
                    }
                    
                    // Individual Test Results
                    if !testRunner.results.isEmpty {
                        testResultsList
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        // Dismiss view
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingConfiguration = true
                        } label: {
                            Label("Configuration", systemImage: "gear")
                        }
                        
                        Button {
                            showingReports = true
                        } label: {
                            Label("Reports", systemImage: "doc.text")
                        }
                        
                        Button {
                            showingLogs = true
                        } label: {
                            Label("Logs", systemImage: "doc.text.magnifyingglass")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            testRunner.clearResults()
                        } label: {
                            Label("Clear Results", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingConfiguration) {
            TestConfigurationView(configuration: $testRunner.configuration)
        }
        .sheet(isPresented: $showingReports) {
            TestReportsView()
        }
        .sheet(isPresented: $showingLogs) {
            TestLogsView()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("V2 API Test Hub")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Comprehensive testing for Interspace backend")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    private var configurationSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Environment")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(testRunner.configuration.useProductionAPI ? "Production" : "Development")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("API Version")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(testRunner.configuration.apiVersion.uppercased())
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var testCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Categories")
                .font(.headline)
            
            ForEach(TestCategory.allCases, id: \.self) { category in
                TestCategoryRow(
                    category: category,
                    isSelected: selectedCategory == category,
                    testCount: testRunner.getTestsForCategory(category).count,
                    passedCount: testRunner.getPassedCountForCategory(category)
                ) {
                    if selectedCategory == category {
                        selectedCategory = nil
                    } else {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    private var runControlsSection: some View {
        VStack(spacing: 12) {
            if let category = selectedCategory {
                Button(action: {
                    Task {
                        await testRunner.runCategoryTests(category)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run \(category.rawValue) Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                Task {
                    await testRunner.runAllTests()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Run All Tests")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(testRunner.isRunning)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: testRunner.progress)
                .progressViewStyle(.linear)
            
            Text("\(testRunner.currentTestName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("\(testRunner.completedTests) of \(testRunner.totalTests) tests")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let timeRemaining = testRunner.estimatedTimeRemaining {
                    Text("~\(Int(timeRemaining))s remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var resultsSummary: some View {
        HStack(spacing: 20) {
            ResultStat(
                title: "Passed",
                value: testRunner.passedCount,
                color: .green
            )
            
            ResultStat(
                title: "Failed",
                value: testRunner.failedCount,
                color: .red
            )
            
            ResultStat(
                title: "Success Rate",
                value: testRunner.successRate,
                color: .blue,
                isPercentage: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var testResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Test Results")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    testRunner.exportResults()
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
            }
            
            ForEach(testRunner.filteredResults(for: selectedCategory), id: \.testName) { result in
                TestResultRow(result: result)
            }
        }
    }
}

// MARK: - Supporting Views

struct TestCategoryRow: View {
    let category: TestCategory
    let isSelected: Bool
    let testCount: Int
    let passedCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 30)
                
                Text(category.rawValue)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if passedCount > 0 {
                    Text("\(passedCount)/\(testCount)")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .secondary)
                } else {
                    Text("\(testCount)")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct ResultStat: View {
    let title: String
    let value: Int
    let color: Color
    var isPercentage: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isPercentage {
                Text("\(value)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.testName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(String(format: "%.2f", result.executionTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let error = result.error {
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}