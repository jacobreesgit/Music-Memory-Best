import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: SongListViewModel
    @Environment(\.isPreview) private var isPreview
    
    // Add a parameter that will only be used in previews
    var previewMode: Bool
    
    init(previewMode: Bool = false, previewSongs: [Song]? = nil) {
        self.previewMode = previewMode || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        if let songs = previewSongs, (previewMode || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
            // Use preview view model with provided songs
            _viewModel = StateObject(wrappedValue: SongListViewModel.preview(withSongs: songs))
        } else {
            // Use standard view model with DI container
            _viewModel = StateObject(wrappedValue: SongListViewModel(
                musicLibraryService: DIContainer.shared.musicLibraryService,
                logger: DIContainer.shared.logger
            ))
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                // For preview, bypass permission check and show content directly
                if previewMode || isPreview {
                    SongListView(viewModel: viewModel)
                } else {
                    // Normal flow for real device
                    switch viewModel.permissionStatus {
                    case .granted:
                        SongListView(viewModel: viewModel)
                    case .denied:
                        PermissionDeniedView(
                            onRetry: { Task { await viewModel.requestPermission() } }
                        )
                    case .notRequested, .unknown:
                        PermissionRequestView(
                            onRequest: { Task { await viewModel.requestPermission() } }
                        )
                    case .requested:
                        ProgressView("Requesting permission...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.background)
                    }
                }
            }
            .navigationTitle("Music Memory")
            .overlay(
                Group {
                    if viewModel.isLoading && !previewMode && !isPreview {
                        LoadingView()
                    }
                }
            )
            .alert(item: $appState.currentError) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.userMessage),
                    dismissButton: .default(Text("OK")) {
                        appState.clearError()
                    }
                )
            }
        }
        .task {
            if !previewMode && !isPreview {
                await viewModel.loadSongs()
            }
        }
    }
}

// Improved previews with proper dependency injection
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(previewMode: true, previewSongs: PreviewSongFactory.mockSongs)
            .previewWithContainer(DIContainer.preview(withMockSongs: PreviewSongFactory.mockSongs))
    }
}
