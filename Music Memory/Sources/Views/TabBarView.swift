import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var appLifecycleManager: AppLifecycleManager
    @StateObject private var songListViewModel: SongListViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var selectedTab = 0
    
    init() {
        // Use updated view model with priority service
        _songListViewModel = StateObject(wrappedValue: SongListViewModel(
            musicLibraryService: DIContainer.shared.musicLibraryService,
            logger: DIContainer.shared.logger,
            rankHistoryService: DIContainer.shared.rankHistoryService,
            priorityService: DIContainer.shared.enhancementPriorityService
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
                        ToolbarItem(placement: .navigationBarTrailing) {
                            // Only show sort button when we have songs to sort
                            if !songListViewModel.songs.isEmpty {
                                SortMenuView(viewModel: songListViewModel)
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
                
                // Settings tab
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
                // Start progressive loading immediately
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

// MARK: - Enhancement Progress View

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
