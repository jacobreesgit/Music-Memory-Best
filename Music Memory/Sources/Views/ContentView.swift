import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @StateObject private var navigationManager = NavigationManager()
    @Environment(\.isPreview) private var isPreview
    
    // Add a parameter that will only be used in previews
    var previewMode: Bool
    var previewSongs: [Song]?
    
    init(previewMode: Bool = false, previewSongs: [Song]? = nil) {
        self.previewMode = previewMode || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        self.previewSongs = previewSongs
    }
    
    var body: some View {
        TabBarView(previewMode: previewMode, previewSongs: previewSongs)
            .environmentObject(navigationManager)
    }
}

// Improved previews with proper dependency injection
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(previewMode: true, previewSongs: PreviewSongFactory.mockSongs)
            .previewWithContainer(DIContainer.preview(withMockSongs: PreviewSongFactory.mockSongs))
    }
}
