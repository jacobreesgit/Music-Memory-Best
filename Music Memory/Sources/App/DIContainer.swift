import Foundation
import SwiftUI

class DIContainer: ObservableObject {
    let musicLibraryService: MusicLibraryServiceProtocol
    let permissionService: PermissionServiceProtocol
    let logger: LoggerProtocol
    let appState: any AppStateProtocol
    let navigationManager: NavigationManager
    let rankHistoryService: RankHistoryServiceProtocol
    let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    let appLifecycleManager: AppLifecycleManager
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        permissionService: PermissionServiceProtocol,
        logger: LoggerProtocol,
        appState: any AppStateProtocol,
        navigationManager: NavigationManager,
        rankHistoryService: RankHistoryServiceProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol,
        appLifecycleManager: AppLifecycleManager
    ) {
        self.musicLibraryService = musicLibraryService
        self.permissionService = permissionService
        self.logger = logger
        self.appState = appState
        self.navigationManager = navigationManager
        self.rankHistoryService = rankHistoryService
        self.artworkPersistenceService = artworkPersistenceService
        self.appLifecycleManager = appLifecycleManager
    }
    
    // Factory method for production
    static func production() -> DIContainer {
        let logger = Logger()
        let permissionService = PermissionService()
        let musicLibraryService = MusicLibraryService(
            permissionService: permissionService,
            logger: logger
        )
        let rankHistoryService = RankHistoryService(logger: logger)
        let artworkPersistenceService = ArtworkPersistenceService(logger: logger)
        let appLifecycleManager = AppLifecycleManager(
            logger: logger,
            artworkPersistenceService: artworkPersistenceService
        )
        let appState = AppState()
        let navigationManager = NavigationManager()
        
        return DIContainer(
            musicLibraryService: musicLibraryService,
            permissionService: permissionService,
            logger: logger,
            appState: appState,
            navigationManager: navigationManager,
            rankHistoryService: rankHistoryService,
            artworkPersistenceService: artworkPersistenceService,
            appLifecycleManager: appLifecycleManager
        )
    }
    
    // Singleton for backward compatibility
    static let shared: DIContainer = production()
}
