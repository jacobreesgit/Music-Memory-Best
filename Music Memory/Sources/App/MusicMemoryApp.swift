import SwiftUI

@main
struct MusicMemoryApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(DIContainer.shared)
        }
    }
}

// Dependency Injection Container
class DIContainer: ObservableObject {
    static let shared = DIContainer()
    
    let musicLibraryService: MusicLibraryServiceProtocol
    let permissionService: PermissionServiceProtocol
    let logger: LoggerProtocol
    let appState: any AppStateProtocol
    
    private init() {
        self.logger = Logger()
        self.permissionService = PermissionService()
        self.musicLibraryService = MusicLibraryService(
            permissionService: permissionService,
            logger: logger
        )
        self.appState = AppState()
    }
}
