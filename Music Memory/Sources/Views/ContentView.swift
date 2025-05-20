import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: SongListViewModel
    
    // Add a parameter that will only be used in previews
    var previewMode: Bool = false
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        // This will be injected via environment in the body
        _viewModel = StateObject(wrappedValue: SongListViewModel(
            musicLibraryService: DIContainer.shared.musicLibraryService,
            logger: DIContainer.shared.logger
        ))
    }
    
    var body: some View {
        NavigationView {
            Group {
                // For preview, bypass permission check and show content directly
                if previewMode {
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
                            .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle("Music Memory")
            .overlay(
                Group {
                    if viewModel.isLoading && !previewMode {
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
            if !previewMode {
                await viewModel.loadSongs()
            }
        }
    }
}

// Improved previews with proper dependency injection
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewWithContainer(DIContainer.preview(withMockSongs: createMockSongs()))
    }
    
    static func createMockSongs() -> [Song] {
        return [
            createMockSong(id: "1", title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", playCount: 42),
            createMockSong(id: "2", title: "Hotel California", artist: "Eagles", album: "Hotel California", playCount: 35),
            createMockSong(id: "3", title: "Hey Jude", artist: "The Beatles", album: "The Beatles (White Album)", playCount: 28)
        ]
    }
    
    static func createMockSong(id: String, title: String, artist: String, album: String, playCount: Int) -> Song {
        let item = MockMPMediaItem()
        item.mockTitle = title
        item.mockArtist = artist
        item.mockAlbumTitle = album
        item.mockPlayCount = playCount
        item.mockPersistentID = MPMediaEntityPersistentID(id.hashValue)
        
        return Song(from: item)
    }
}
