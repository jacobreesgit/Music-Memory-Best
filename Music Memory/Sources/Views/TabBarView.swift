import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var appLifecycleManager: AppLifecycleManager
    @StateObject private var songListViewModel: SongListViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var selectedTab = 0
    
    // CRITICAL FIX: Updated initialization with all required dependencies
    init() {
        // Create view model with all cache services properly injected
        _songListViewModel = StateObject(wrappedValue: SongListViewModel(
            musicLibraryService: DIContainer.shared.musicLibraryService,
            logger: DIContainer.shared.logger,
            rankHistoryService: DIContainer.shared.rankHistoryService,
            priorityService: DIContainer.shared.enhancementPriorityService,
            enhancedSongCacheService: DIContainer.shared.enhancedSongCacheService,
            cacheManagementService: DIContainer.shared.cacheManagementService
        ))
        
        // Initialize settings view model
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(
            settingsService: DIContainer.shared.settingsService,
            logger: DIContainer.shared.logger
        ))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main TabView with selection binding
            TabView(selection: $selectedTab) {
                // Library tab
                NavigationStack(path: $navigationManager.songListPath) {
                    Group {
                        // Progressive loading flow - show content immediately when permission is granted
                        switch songListViewModel.permissionStatus {
                        case .granted:
                            VStack {
                                SongListView(viewModel: songListViewModel)
                                
                                // Show enhancement progress for debugging/transparency
                                if songListViewModel.enhancementProgress.isEnhancing {
                                    EnhancementProgressView(
                                        progress: songListViewModel.enhancementProgress,
                                        stats: songListViewModel.enhancementStats
                                    )
                                }
                            }
                        case .denied:
                            PermissionDeniedView(
                                onRetry: { Task { await songListViewModel.requestPermission() } }
                            )
                        case .notRequested, .unknown:
                            PermissionRequestView(
                                onRequest: { Task { await songListViewModel.requestPermission() } }
                            )
                        case .requested:
                            ProgressView("Requesting permission...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(AppColors.background)
                        }
                    }
                    .navigationTitle("Library")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbar {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            // Only show controls when we have songs to sort
                            if !songListViewModel.songs.isEmpty {
                                HStack(spacing: AppSpacing.small) {
                                    // CRITICAL FIX: Cache health indicator
                                    CacheHealthIndicator(viewModel: songListViewModel)
                                    
                                    SortMenuView(viewModel: songListViewModel)
                                }
                            }
                        }
                    }
                    .navigationDestination(for: Song.self) { song in
                        SongDetailView(
                            viewModel: SongDetailViewModel(
                                song: song,
                                logger: DIContainer.shared.logger
                            )
                        )
                    }
                    .overlay(
                        Group {
                            // Only show loading overlay for initial permission/MediaPlayer load
                            // Progressive enhancement happens in background without blocking UI
                            if songListViewModel.isLoading {
                                LoadingView()
                            }
                        }
                    )
                }
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(0)
                
                // Settings tab with cache management
                SettingsView(viewModel: settingsViewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(1)
            }
            .accentColor(AppColors.primary)
            .onAppear {
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithDefaultBackground()
                UITabBar.appearance().standardAppearance = tabBarAppearance
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // Detect when Library tab (0) is tapped
                if newValue == 0 && oldValue == 0 {
                    // User tapped Library tab while already on Library tab
                    // Check if we're in a detail view (navigation path is not empty)
                    if !navigationManager.songListPath.isEmpty {
                        // Provide success haptic feedback for successful navigation back to root
                        AppHaptics.success()
                        // Pop to root when Library tab is tapped while in detail view
                        navigationManager.popToRoot()
                    }
                }
            }
            .onChange(of: songListViewModel.songs) { oldValue, newValue in
                // Update the NowPlayingViewModel with the current songs list whenever it changes
                // This includes progressive updates as songs are enhanced
                NowPlayingViewModel.shared.updateSongsList(newValue)
            }
            .alert(item: $appState.currentError) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.userMessage),
                    dismissButton: .default(Text("OK")) {
                        appState.clearError()
                    }
                )
            }
            .task {
                // Start progressive loading immediately with cache integration
                await songListViewModel.loadSongs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .localDataCleared)) { _ in
                // Refresh the song list when local data is cleared
                Task {
                    await songListViewModel.loadSongs()
                }
            }

            // Now Playing Bar - show on all tabs
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    NowPlayingBar()
                        .offset(y: -geometry.safeAreaInsets.bottom - 49 - AppSpacing.small) // Spacing between tab and now playing bar
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // Ensure the NowPlayingViewModel has the current songs list on appear
            if !songListViewModel.songs.isEmpty {
                NowPlayingViewModel.shared.updateSongsList(songListViewModel.songs)
            }
        }
    }
}

struct SortMenuView: View {
    @ObservedObject var viewModel: SongListViewModel
    
    var body: some View {
        Menu {
            // Sort by options with direction indicators
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.updateSortDescriptor(option: option)
                } label: {
                    HStack {
                        Label(option.rawValue, systemImage: option.systemImage)
                        
                        Spacer()
                        
                        // Show current direction for selected option
                        if viewModel.sortDescriptor.option == option {
                            Image(systemName: viewModel.sortDescriptor.direction.systemImage)
                        }
                    }
                }
            }
            
            Divider()
            
            // CRITICAL FIX: Add cache management options
            Button {
                viewModel.performManualCacheCleanup()
            } label: {
                Label("Clean Cache", systemImage: "arrow.clockwise")
            }
            
        } label: {
            // Show current sort option icon and direction in the toolbar button
            HStack(spacing: AppSpacing.tiny) {
                Image(systemName: viewModel.sortDescriptor.option.systemImage)
                    .font(.system(size: 16))
                
                Image(systemName: viewModel.sortDescriptor.direction.systemImage)
                    .font(.system(size: 14))
            }
            .foregroundColor(AppColors.primary)
        }
    }
}

// CRITICAL FIX: Cache health indicator
struct CacheHealthIndicator: View {
    @ObservedObject var viewModel: SongListViewModel
    @State private var healthScore: Double = 1.0
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            Circle()
                .fill(healthColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(healthColor.opacity(0.3), lineWidth: 1)
                        .frame(width: 12, height: 12)
                )
        }
        .onAppear {
            updateHealthScore()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            updateHealthScore()
        }
        .sheet(isPresented: $showingDetail) {
            CacheHealthDetailView(viewModel: viewModel)
        }
    }
    
    private var healthColor: Color {
        if healthScore >= 0.8 {
            return AppColors.success
        } else if healthScore >= 0.5 {
            return AppColors.warning
        } else {
            return AppColors.destructive
        }
    }
    
    private func updateHealthScore() {
        Task {
            let score = viewModel.getCacheHealthScore()
            await MainActor.run {
                self.healthScore = score
            }
        }
    }
}

// CRITICAL FIX: Cache health detail view
struct CacheHealthDetailView: View {
    @ObservedObject var viewModel: SongListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var cacheStats: CacheStatistics?
    @State private var healthScore: Double = 1.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    // Health Score Header
                    AppCard {
                        VStack(spacing: AppSpacing.small) {
                            HStack {
                                Circle()
                                    .fill(healthColor)
                                    .frame(width: 12, height: 12)
                                
                                HeadlineText(text: "Cache Health")
                                
                                Spacer()
                                
                                Text(String(format: "%.1f%%", healthScore * 100))
                                    .font(AppFonts.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(healthColor)
                            }
                            
                            Text(healthDescription)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Cache Statistics
                    if let stats = cacheStats {
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Cache Statistics")
                                
                                VStack(alignment: .leading, spacing: AppSpacing.small) {
                                    StatRow(label: "Total Size", value: stats.totalDataSize)
                                    StatRow(label: "Total Entries", value: "\(stats.totalUserDefaultsKeys)")
                                    StatRow(label: "Valid Entries", value: "\(stats.validCacheEntries)")
                                    
                                    if stats.staleCacheEntries > 0 {
                                        StatRow(label: "Stale Entries", value: "\(stats.staleCacheEntries)", color: AppColors.warning)
                                    }
                                    
                                    if stats.corruptedCacheEntries > 0 {
                                        StatRow(label: "Corrupted Entries", value: "\(stats.corruptedCacheEntries)", color: AppColors.destructive)
                                    }
                                }
                            }
                        }
                        
                        // Cache Breakdown
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Cache Breakdown")
                                
                                VStack(alignment: .leading, spacing: AppSpacing.small) {
                                    StatRow(label: "Enhanced Songs", value: "\(stats.enhancedSongEntries)")
                                    StatRow(label: "Artwork Cache", value: "\(stats.artworkEntries)")
                                    StatRow(label: "Search Cache", value: "\(stats.musicKitSearchEntries)")
                                    StatRow(label: "Rank History", value: "\(stats.rankHistoryEntries)")
                                    StatRow(label: "Play Counts", value: "\(stats.playCountEntries)")
                                }
                            }
                        }
                    }
                    
                    // Actions
                    AppCard {
                        VStack(spacing: AppSpacing.small) {
                            Button("Refresh Cache Health") {
                                refreshData()
                            }
                            .secondaryStyle()
                            
                            Button("Clean Cache Now") {
                                viewModel.performManualCacheCleanup()
                                refreshData()
                            }
                            .primaryStyle()
                        }
                    }
                }
                .padding(AppSpacing.medium)
            }
            .navigationTitle("Cache Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshData()
            }
        }
    }
    
    private var healthColor: Color {
        if healthScore >= 0.8 {
            return AppColors.success
        } else if healthScore >= 0.5 {
            return AppColors.warning
        } else {
            return AppColors.destructive
        }
    }
    
    private var healthDescription: String {
        if healthScore >= 0.8 {
            return "Cache system is healthy and optimized"
        } else if healthScore >= 0.5 {
            return "Cache system has minor issues but is functional"
        } else {
            return "Cache system needs attention"
        }
    }
    
    private func refreshData() {
        Task {
            let stats = viewModel.getCacheStatistics()
            let health = viewModel.getCacheHealthScore()
            
            await MainActor.run {
                self.cacheStats = stats
                self.healthScore = health
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = AppColors.primaryText
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.body)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Enhancement Progress View (Updated with cache info)

struct EnhancementProgressView: View {
    let progress: EnhancementProgress
    let stats: EnhancementStats
    
    var body: some View {
        VStack(spacing: AppSpacing.tiny) {
            HStack {
                Text("Smart Enhancement")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Spacer()
                
                Text("\(progress.enhancedCount)/\(progress.totalCount)")
                    .font(AppFonts.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
            }
            
            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: AppColors.primary))
                .scaleEffect(y: 0.5)
            
            // Priority breakdown (only show if there are queued items)
            if stats.queuedSongs > 0 {
                HStack(spacing: AppSpacing.small) {
                    if stats.urgentRemaining > 0 {
                        PriorityIndicator(count: stats.urgentRemaining, color: .red, label: "Urgent")
                    }
                    if stats.highRemaining > 0 {
                        PriorityIndicator(count: stats.highRemaining, color: .orange, label: "High")
                    }
                    if stats.mediumRemaining > 0 {
                        PriorityIndicator(count: stats.mediumRemaining, color: .yellow, label: "Medium")
                    }
                    if stats.lowRemaining > 0 {
                        PriorityIndicator(count: stats.lowRemaining, color: .blue, label: "Low")
                    }
                    if stats.backgroundRemaining > 0 {
                        PriorityIndicator(count: stats.backgroundRemaining, color: .gray, label: "Background")
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(AppColors.secondaryBackground)
        .cornerRadius(AppRadius.small)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.bottom, AppSpacing.small)
    }
}

struct PriorityIndicator: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.secondaryText)
        }
    }
}
