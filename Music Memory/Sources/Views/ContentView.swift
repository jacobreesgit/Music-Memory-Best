import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: SongListViewModel
    
    init() {
        // This will be injected via environment in the body
        _viewModel = StateObject(wrappedValue: SongListViewModel(
            musicLibraryService: DIContainer.shared.musicLibraryService,
            logger: DIContainer.shared.logger
        ))
    }
    
    var body: some View {
        NavigationView {
            Group {
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
                }
            }
            .navigationTitle("Music Memory")
            .overlay(
                Group {
                    if viewModel.isLoading {
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
            await viewModel.loadSongs()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(DIContainer.shared)
    }
}
