import Foundation
import SwiftUI

class DIContainer: ObservableObject {
    let musicLibraryService: MusicLibraryServiceProtocol
    let permissionService: PermissionServiceProtocol
    let logger: LoggerProtocol
    let appState: any AppStateProtocol
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        permissionService: PermissionServiceProtocol,
        logger: LoggerProtocol,
        appState: any AppStateProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.permissionService = permissionService
        self.logger = logger
        self.appState = appState
    }
    
    // Factory method for production
    static func production() -> DIContainer {
        let logger = Logger()
        let permissionService = PermissionService()
        let musicLibraryService = MusicLibraryService(
            permissionService: permissionService,
            logger: logger
        )
        let appState = AppState()
        
        return DIContainer(
            musicLibraryService: musicLibraryService,
            permissionService: permissionService,
            logger: logger,
            appState: appState
        )
    }
    
    // Factory method for previews
    static func preview(withMockSongs songs: [Song] = []) -> DIContainer {
        let logger = Logger()
        let permissionService = PreviewPermissionService(status: .granted)
        let musicLibraryService = PreviewMusicLibraryService(mockSongs: songs)
        let appState = AppState()
        appState.musicLibraryPermissionStatus = .granted
        
        return DIContainer(
            musicLibraryService: musicLibraryService,
            permissionService: permissionService,
            logger: logger,
            appState: appState
        )
    }
    
    // Singleton for backward compatibility
    static let shared: DIContainer = production()
}
