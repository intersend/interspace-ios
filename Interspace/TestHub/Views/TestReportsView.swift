import SwiftUI

struct TestReportsView: View {
    @State private var reports: [URL] = []
    @State private var selectedReport: TestReport?
    @State private var showingExportOptions = false
    @State private var showingDeleteAlert = false
    @State private var reportToDelete: URL?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if reports.isEmpty {
                    emptyState
                } else {
                    reportsList
                }
            }
            .navigationTitle("Test Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !reports.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .onAppear {
                loadReports()
            }
        }
        .sheet(item: $selectedReport) { report in
            TestReportDetailView(report: report)
        }
        .confirmationDialog("Export Report", isPresented: $showingExportOptions) {
            Button("Export as JSON") {
                exportReport(as: .json)
            }
            Button("Export as CSV") {
                exportReport(as: .csv)
            }
            Button("Export as HTML") {
                exportReport(as: .html)
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete All Reports", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllReports()
            }
        } message: {
            Text("This will permanently delete all test reports.")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Test Reports")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Run tests to generate reports")
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var reportsList: some View {
        List {
            ForEach(reports, id: \.self) { url in
                ReportRow(url: url) {
                    if let report = TestReporter.shared.loadReport(from: url) {
                        selectedReport = report
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        reportToDelete = url
                        deleteReport(at: url)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private func loadReports() {
        reports = TestReporter.shared.getAllReports()
    }
    
    private func deleteReport(at url: URL) {
        TestReporter.shared.deleteReport(at: url)
        loadReports()
    }
    
    private func deleteAllReports() {
        TestReporter.shared.deleteAllReports()
        loadReports()
    }
    
    private func exportReport(as format: ExportFormat) {
        // Implementation would depend on sharing capabilities
    }
    
    enum ExportFormat {
        case json, csv, html
    }
}

struct ReportRow: View {
    let url: URL
    let action: () -> Void
    
    @State private var report: TestReport?
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let report = report {
                    HStack {
                        Label("\(report.summary.passed)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Label("\(report.summary.failed)", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Text(formatDate(report.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            report = TestReporter.shared.loadReport(from: url)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TestReportDetailView: View {
    let report: TestReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    summarySection
                    
                    // Environment
                    environmentSection
                    
                    // Results by Category
                    resultsByCategorySection
                    
                    // Individual Results
                    individualResultsSection
                }
                .padding()
            }
            .navigationTitle("Test Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Total Tests")
                    Spacer()
                    Text("\(report.summary.totalTests)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Passed")
                    Spacer()
                    Text("\(report.summary.passed)")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Failed")
                    Spacer()
                    Text("\(report.summary.failed)")
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Success Rate")
                    Spacer()
                    Text("\(Int(report.summary.successRate * 100))%")
                        .fontWeight(.medium)
                        .foregroundColor(report.summary.successRate > 0.8 ? .green : .orange)
                }
                
                HStack {
                    Text("Total Time")
                    Spacer()
                    Text(String(format: "%.2fs", report.summary.totalExecutionTime))
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Device: \(report.environment.device)")
                Text("iOS: \(report.environment.osVersion)")
                Text("App Version: \(report.environment.appVersion) (\(report.environment.buildNumber))")
                Text("API: \(report.environment.apiVersion) - \(report.environment.baseURL)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var resultsByCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results by Category")
                .font(.headline)
            
            ForEach(TestCategory.allCases, id: \.self) { category in
                let categoryResults = report.results.filter { $0.category == category.rawValue }
                if !categoryResults.isEmpty {
                    HStack {
                        Image(systemName: category.icon)
                            .frame(width: 20)
                        
                        Text(category.rawValue)
                        
                        Spacer()
                        
                        let passed = categoryResults.filter { $0.success }.count
                        let total = categoryResults.count
                        
                        Text("\(passed)/\(total)")
                            .font(.caption)
                            .foregroundColor(passed == total ? .green : .orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var individualResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Individual Results")
                .font(.headline)
            
            ForEach(report.results, id: \.testName) { result in
                TestResultRow(result: result)
            }
        }
    }
}