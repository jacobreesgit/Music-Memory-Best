import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @StateObject private var songListViewModel: SongListViewModel
    @Environment(\.isPreview) private var isPreview
    
    // For preview support
    var previewMode: Bool
    
    init(previewMode: Bool = false, previewSongs: [Song]? = nil) {
        self.previewMode = previewMode || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        if let songs = previewSongs, (previewMode || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
            // Use preview view model with provided songs
            _songListViewModel = StateObject(wrappedValue: SongListViewModel.preview(withSongs: songs))
        } else {
            // Use standard view model with DI container
            _songListViewModel = StateObject(wrappedValue: SongListViewModel(
                musicLibraryService: DIContainer.shared.musicLibraryService,
                logger: DIContainer.shared.logger
            ))
        }
    }
    
    var body: some View {
        TabView {
            // Library tab
            NavigationStack {
                Group {
                    // For preview, bypass permission check and show content directly
                    if previewMode || isPreview {
                        SongListView(viewModel: songListViewModel)
                    } else {
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
                }
                .navigationTitle("Library")
                .overlay(
                    Group {
                        if songListViewModel.isLoading && !previewMode && !isPreview {
                            LoadingView()
                        }
                    }
                )
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(AppColors.secondaryBackground, for: .tabBar)
            }
            .tabItem {
                Label("Library", systemImage: "music.note.list")
            }
            
            // Additional tabs can be added here in the future if needed
        }
        .accentColor(AppColors.primary)
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
            if !previewMode && !isPreview {
                await songListViewModel.loadSongs()
            }
        }
    }
}
