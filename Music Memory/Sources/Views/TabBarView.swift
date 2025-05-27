import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var appLifecycleManager: AppLifecycleManager
    @StateObject private var songListViewModel: SongListViewModel
    @State private var selectedTab = 0
    
    init() {
        // Use updated view model with rank history service
        _songListViewModel = StateObject(wrappedValue: SongListViewModel(
            musicLibraryService: DIContainer.shared.musicLibraryService,
            logger: DIContainer.shared.logger,
            rankHistoryService: DIContainer.shared.rankHistoryService
        ))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main TabView with selection binding
            TabView(selection: $selectedTab) {
                // Library tab
                NavigationStack(path: $navigationManager.songListPath) {
                    Group {
                        // Normal flow for real device
                        switch songListViewModel.permissionStatus {
                        case .granted:
                            SongListView(viewModel: songListViewModel)
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
            }
            .accentColor(AppColors.primary)
            .onAppear {
                // Set tab bar appearance to use solid colors instead of material
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
                await songListViewModel.loadSongs()
            }

            // Now Playing Bar
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
