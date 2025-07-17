import SwiftUI

struct AppStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appsViewModel: AppsViewModel
    var onDismiss: (() -> Void)?
    
    @State private var categories: [AppStoreCategory] = []
    @State private var featuredApps: [AppStoreApp] = []
    @State private var categoryApps: [AppStoreApp] = []
    @State private var selectedCategory: AppStoreCategory?
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var currentPage = 1
    @State private var hasMorePages = false
    @State private var isLoadingMore = false
    @State private var addedAppIds = Set<String>()
    @State private var searchTask: Task<Void, Never>?
    
    // Smooth category switching states
    @State private var isCategorySwitching = false
    // REMOVED: categoryCache was causing stale data issues
    @State private var preloadTask: Task<Void, Never>?
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header with search
                customHeader
                
                if isLoading && categories.isEmpty {
                    // Initial loading state
                    Spacer()
                    AppStoreLoadingView()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if searchText.isEmpty {
                                // Categories
                                if !categories.isEmpty {
                                    categoriesSection
                                        .padding(.top, 20)
                                        .padding(.bottom, 20)
                                }
                                
                                // Featured Section
                                if !featuredApps.isEmpty {
                                    featuredSection
                                        .padding(.bottom, 30)
                                }
                                
                                // Apps List with smooth transition
                                ZStack {
                                    if isCategorySwitching {
                                        skeletonAppsSection
                                    } else {
                                        appsListSection
                                    }
                                }
                                .animation(.easeInOut(duration: 0.3), value: isCategorySwitching)
                            } else {
                                // Search Results
                                searchResultsSection
                                    .padding(.top, 20)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await loadData()
                    }
                }
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            #if DEBUG
            print("🎯 AppStoreView: onAppear triggered - categories: \(categories.count), isLoading: \(isLoading)")
            #endif
            
            // Only load data if we haven't loaded it yet
            if categories.isEmpty {
                Task {
                    await loadData()
                    updateAddedApps()
                }
            } else {
                updateAddedApps()
            }
        }
        .onChange(of: appsViewModel.apps) { _ in
            updateAddedApps()
        }
    }
    
    // MARK: - View Components
    
    private var customHeader: some View {
        VStack(spacing: 0) {
            // Add safe area top padding
            Color.clear
                .frame(height: 0)
                .padding(.top)
            
            HStack(spacing: 12) {
                // Full-width search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(UIColor.systemGray2))
                        .font(.system(size: 16))
                    
                    TextField("App, Link, ...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await searchApps()
                            }
                        }
                        .onChange(of: searchText) { _ in
                            // Cancel previous search
                            searchTask?.cancel()
                            
                            // Debounced search
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                if !Task.isCancelled && !searchText.isEmpty {
                                    await searchApps()
                                }
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            isSearchFocused = false
                            categoryApps = []
                            searchTask?.cancel()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(UIColor.systemGray2))
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6).opacity(0.12))
                .cornerRadius(10)
                
                // Close button
                Button(action: { 
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(UIColor.systemGray2))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.001))
        }
    }
    
    private var featuredSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(featuredApps) { app in
                    FeaturedAppCard(
                        app: app,
                        isAdded: isAppAdded(app)
                    ) {
                        await addApp(app)
                    }
                    .frame(width: UIScreen.main.bounds.width - 40)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var categoriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Apps pill
                CategoryPill(
                    name: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: {
                        Task { await switchToCategory(nil) }
                    }
                )
                
                ForEach(categories) { category in
                    CategoryPill(
                        name: category.name,
                        icon: category.displayIcon,
                        isSelected: selectedCategory?.id == category.id,
                        action: {
                            Task { await switchToCategory(category) }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var appsListSection: some View {
        VStack(spacing: 0) {
            if categoryApps.isEmpty && !isLoading {
                emptyStateView
            } else {
                ForEach(categoryApps) { app in
                    AppStoreRowView(
                        app: app,
                        isAdded: isAppAdded(app)
                    ) {
                        await addApp(app)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                if isLoadingMore {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.vertical, 20)
                }
                
                if hasMorePages && !isLoadingMore {
                    Button(action: { Task { await loadMoreApps() } }) {
                        Text("Load More")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                            .padding(.vertical, 20)
                    }
                }
            }
        }
    }
    
    private var searchResultsSection: some View {
        VStack(spacing: 0) {
            if categoryApps.isEmpty && !isLoading && !searchText.isEmpty {
                // Show custom app option when no results
                CustomAppRow(
                    searchText: searchText,
                    isAdded: isCustomAppAdded(searchText)
                ) { name, url in
                    await addCustomApp(name: name, url: url)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            } else {
                ForEach(categoryApps) { app in
                    AppStoreRowView(
                        app: app,
                        isAdded: isAppAdded(app)
                    ) {
                        await addApp(app)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .animation(.default, value: categoryApps)
                
                // Also show custom app option at the bottom if searching
                if !searchText.isEmpty && !categoryApps.isEmpty {
                    CustomAppRow(
                        searchText: searchText,
                        isAdded: isCustomAppAdded(searchText)
                    ) { name, url in
                        await addCustomApp(name: name, url: url)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .padding(.top, 20)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Animated icon
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(Color(UIColor.systemGray2))
            
            VStack(spacing: 8) {
                Text("No Apps Available")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Check your connection or try again later")
                    .font(.system(size: 16))
                    .foregroundColor(Color(UIColor.systemGray))
                    .multilineTextAlignment(.center)
            }
            
            // Retry button
            Button(action: {
                Task {
                    await loadData()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("Try Again")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 0.0, green: 0.478, blue: 1.0))
                .cornerRadius(20)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
        .padding(.top, 80)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private var skeletonAppsSection: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                SkeletonAppRow()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        )
                    )
                    .animation(
                        .easeOut(duration: 0.3).delay(Double(index) * 0.05),
                        value: isCategorySwitching
                    )
            }
        }
    }
    
    // MARK: - Helper Methods for Smooth Transitions
    
    private func switchToCategory(_ category: AppStoreCategory?) async {
        // Start transition
        withAnimation(.easeInOut(duration: 0.15)) {
            isCategorySwitching = true
        }
        
        // Update selection with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedCategory = category
        }
        
        // Load category data
        // Small delay to show skeleton smoothly
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        await loadCategoryApps()
    }
    
    private func refreshCategoryData() async {
        do {
            let result = try await AppStoreAPI.shared.getAppsByCategory(
                categorySlug: selectedCategory?.slug ?? "",
                page: 1
            )
            
            // Update UI directly without caching
            withAnimation(.easeInOut(duration: 0.2)) {
                categoryApps = result.apps
                hasMorePages = result.pagination?.hasNext ?? false
            }
        } catch {
            // Silently fail for background refresh
        }
    }
    
    private func preloadAdjacentCategories() async {
        guard !categories.isEmpty else { return }
        
        preloadTask?.cancel()
        preloadTask = Task {
            // Find current index
            let currentIndex = selectedCategory.flatMap { selected in
                categories.firstIndex(where: { $0.id == selected.id })
            } ?? -1
            
            // Preload previous and next categories
            var categoriesToPreload: [AppStoreCategory] = []
            
            if currentIndex > 0 {
                categoriesToPreload.append(categories[currentIndex - 1])
            }
            if currentIndex >= 0 && currentIndex < categories.count - 1 {
                categoriesToPreload.append(categories[currentIndex + 1])
            }
            
            // Preload "All" if not selected
            if selectedCategory != nil {
                categoriesToPreload.append(AppStoreCategory(
                    id: "all",
                    name: "All",
                    slug: "",
                    description: nil,
                    icon: nil,
                    position: -1,
                    appsCount: nil,
                    createdAt: "",
                    updatedAt: ""
                ))
            }
            
            // Preloading removed - always fetch fresh data from backend
            // This ensures the backend is the single source of truth
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        showError = false
        
        do {
            // Load categories and featured apps in parallel
            async let categoriesTask = AppStoreAPI.shared.getCategories()
            async let featuredTask = AppStoreAPI.shared.getFeaturedApps()
            
            let (fetchedCategories, fetchedFeatured) = try await (categoriesTask, featuredTask)
            
            categories = fetchedCategories
            featuredApps = fetchedFeatured
            
            #if DEBUG
            print("🎯 AppStoreView: Loaded \(categories.count) categories and \(featuredApps.count) featured apps")
            #endif
            
            // Load initial apps
            isLoading = false
            await loadCategoryApps()
            
        } catch let apiError as APIError {
            #if DEBUG
            print("🔴 AppStoreView: API error loading data: \(apiError)")
            #endif
            
            switch apiError {
            case .unauthorized:
                errorMessage = "Authentication required. Please sign in again."
            case .apiError(let message):
                errorMessage = message
            case .requestFailed(let error):
                errorMessage = "Network error: \(error.localizedDescription)"
            case .invalidResponse(let statusCode):
                errorMessage = "Server error (code: \(statusCode))"
            case .decodingFailed(_):
                errorMessage = "Invalid data format received from server"
            default:
                errorMessage = "Failed to load app store data"
            }
            
            showError = true
            isLoading = false
            
            // Set empty arrays to prevent crashes
            if categories.isEmpty {
                categories = []
            }
            if featuredApps.isEmpty {
                featuredApps = []
            }
            
        } catch {
            #if DEBUG
            print("🔴 AppStoreView: Unknown error loading data: \(error)")
            #endif
            
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showError = true
            isLoading = false
            
            // Set empty arrays to prevent crashes
            categories = []
            featuredApps = []
        }
    }
    
    private func loadCategoryApps() async {
        currentPage = 1
        
        // Always fetch fresh data from backend - no caching
        do {
            let result = try await AppStoreAPI.shared.getAppsByCategory(
                categorySlug: selectedCategory?.slug ?? "",
                page: currentPage
            )
            
            #if DEBUG
            print("🎯 AppStoreView: Loaded \(result.apps.count) apps for category: \(selectedCategory?.name ?? "All")")
            #endif
            
            withAnimation(.easeInOut(duration: 0.3)) {
                categoryApps = result.apps
                hasMorePages = result.pagination?.hasNext ?? false
                isCategorySwitching = false
            }
            
        } catch let apiError as APIError {
            #if DEBUG
            print("🔴 AppStoreView: API error loading category apps: \(apiError)")
            #endif
            
            // Don't show error alert for category loading - just show empty state
            withAnimation(.easeInOut(duration: 0.3)) {
                categoryApps = []
                hasMorePages = false
                isCategorySwitching = false
            }
            
            // Only show error for critical failures
            switch apiError {
            case .unauthorized:
                errorMessage = "Authentication required. Please sign in again."
                showError = true
            case .invalidResponse(let statusCode) where statusCode >= 500:
                errorMessage = "Server error. Please try again later."
                showError = true
            default:
                // For other errors, just show empty state without alert
                break
            }
            
        } catch {
            #if DEBUG
            print("🔴 AppStoreView: Unknown error loading category apps: \(error)")
            #endif
            
            withAnimation(.easeInOut(duration: 0.3)) {
                categoryApps = []
                hasMorePages = false
                isCategorySwitching = false
            }
        }
    }
    
    private func loadMoreApps() async {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        do {
            let result = try await AppStoreAPI.shared.getAppsByCategory(
                categorySlug: selectedCategory?.slug ?? "",
                page: currentPage
            )
            
            categoryApps.append(contentsOf: result.apps)
            hasMorePages = result.pagination?.hasNext ?? false
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            currentPage -= 1
        }
        
        isLoadingMore = false
    }
    
    private func searchApps() async {
        guard !searchText.isEmpty else { 
            categoryApps = []
            return 
        }
        
        // Show loading state for search
        withAnimation(.easeInOut(duration: 0.2)) {
            isCategorySwitching = true
        }
        
        do {
            let results = try await AppStoreAPI.shared.searchApps(query: searchText)
            
            #if DEBUG
            print("🎯 AppStoreView: Search found \(results.count) apps for query: \(searchText)")
            #endif
            
            withAnimation(.easeInOut(duration: 0.3)) {
                categoryApps = results
                isCategorySwitching = false
            }
        } catch {
            #if DEBUG
            print("🔴 AppStoreView: Search error: \(error)")
            #endif
            
            withAnimation(.easeInOut(duration: 0.3)) {
                categoryApps = []
                isCategorySwitching = false
            }
            
            // Don't show error alerts for search - just show empty state
            if case APIError.unauthorized = error {
                errorMessage = "Authentication required. Please sign in again."
                showError = true
            }
        }
    }
    
    private func addApp(_ app: AppStoreApp) async {
        let request = CreateAppRequest(
            name: app.name,
            url: app.url,
            iconUrl: app.iconUrl,
            folderId: nil,
            position: 0
        )
        
        await appsViewModel.addApp(request)
        
        HapticManager.notification(.success)
        // Don't dismiss - keep user in the store
        updateAddedApps()
    }
    
    private func addCustomApp(name: String, url: String) async {
        // Format URL properly
        let formattedURL = formatURL(url)
        
        let request = CreateAppRequest(
            name: name,
            url: formattedURL,
            iconUrl: nil,
            folderId: nil,
            position: 0
        )
        
        await appsViewModel.addApp(request)
        
        HapticManager.notification(.success)
        updateAddedApps()
        
        // Fetch metadata in background
        Task {
            await appsViewModel.fetchMetadataForApp(url: formattedURL)
        }
    }
    
    private func updateAddedApps() {
        addedAppIds = Set(appsViewModel.apps.map { $0.url })
    }
    
    private func isAppAdded(_ app: AppStoreApp) -> Bool {
        addedAppIds.contains(app.url)
    }
    
    private func isCustomAppAdded(_ searchText: String) -> Bool {
        let url = formatURL(searchText)
        return addedAppIds.contains(url)
    }
    
    private func formatURL(_ input: String) -> String {
        let url = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it already looks like a URL, use it
        if url.contains("://") {
            return url
        }
        
        // If it has a dot, assume it's a domain
        if url.contains(".") {
            return "https://\(url)"
        }
        
        // Otherwise, append .com
        return "https://\(url).com"
    }
}

// MARK: - Loading View

private struct AppStoreLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Custom loading indicator
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.0, green: 0.478, blue: 1.0),
                                Color(red: 0.0, green: 0.478, blue: 1.0).opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.2)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            VStack(spacing: 4) {
                Text("Loading Store")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Fetching apps from server...")
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Custom App Row

private struct CustomAppRow: View {
    let searchText: String
    let isAdded: Bool
    let onAdd: (String, String) async -> Void
    
    @State private var isAdding = false
    
    private var suggestedURL: String {
        if searchText.contains(".") {
            return searchText
        } else {
            return "\(searchText).com"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Generic app icon
            ZStack {
                RoundedRectangle(cornerRadius: 13.4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "globe")
                    .font(.system(size: 30))
                    .foregroundColor(Color(UIColor.systemGray2))
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 2) {
                Text(searchText)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(suggestedURL)
                    .font(.system(size: 15))
                    .foregroundColor(Color(UIColor.systemGray))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 16)
            
            // Add Button
            Button(action: {
                guard !isAdded else { return }
                Task {
                    isAdding = true
                    await onAdd(searchText, suggestedURL)
                    isAdding = false
                }
            }) {
                if isAdding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.0, green: 0.478, blue: 1.0)))
                        .scaleEffect(0.8)
                        .frame(width: 75, height: 30)
                } else {
                    Text(isAdded ? "Added" : "Add")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(
                            isAdded 
                                ? Color(UIColor.systemGray2)
                                : Color(red: 0.0, green: 0.478, blue: 1.0)
                        )
                        .frame(width: 75, height: 30)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(15)
                }
            }
            .disabled(isAdding || isAdded)
            .animation(.easeInOut(duration: 0.2), value: isAdded)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Skeleton Loading View

private struct SkeletonAppRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // App icon skeleton
            RoundedRectangle(cornerRadius: 13.4)
                .fill(shimmerGradient)
                .frame(width: 60, height: 60)
            
            // App info skeleton
            VStack(alignment: .leading, spacing: 8) {
                // App name
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 140, height: 20)
                
                // Developer name
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 100, height: 16)
            }
            
            Spacer(minLength: 16)
            
            // Button skeleton
            RoundedRectangle(cornerRadius: 15)
                .fill(shimmerGradient)
                .frame(width: 75, height: 30)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(
                colors: [
                    Color(UIColor.systemGray6).opacity(0.3),
                    Color(UIColor.systemGray5).opacity(0.5),
                    Color(UIColor.systemGray6).opacity(0.3)
                ]
            ),
            startPoint: isAnimating ? .trailing : .leading,
            endPoint: isAnimating ? .leading : .trailing
        )
    }
}

// MARK: - Preview

struct AppStoreView_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreView(appsViewModel: AppsViewModel())
            .preferredColorScheme(.dark)
    }
}
