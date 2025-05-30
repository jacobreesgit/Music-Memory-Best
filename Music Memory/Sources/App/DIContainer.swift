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
    let settingsService: SettingsServiceProtocol
    let enhancementPriorityService: EnhancementPriorityServiceProtocol
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        permissionService: PermissionServiceProtocol,
        logger: LoggerProtocol,
        appState: any AppStateProtocol,
        navigationManager: NavigationManager,
        rankHistoryService: RankHistoryServiceProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol,
        appLifecycleManager: AppLifecycleManager,
        settingsService: SettingsServiceProtocol,
        enhancementPriorityService: EnhancementPriorityServiceProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.permissionService = permissionService
        self.logger = logger
        self.appState = appState
        self.navigationManager = navigationManager
        self.rankHistoryService = rankHistoryService
        self.artworkPersistenceService = artworkPersistenceService
        self.appLifecycleManager = appLifecycleManager
        self.settingsService = settingsService
        self.enhancementPriorityService = enhancementPriorityService
    }
    
    // Factory method for production
    static func production() -> DIContainer {
        let logger = Logger()
        let permissionService = PermissionService()
        let rankHistoryService = RankHistoryService(logger: logger)
        let artworkPersistenceService = ArtworkPersistenceService(logger: logger)
        let enhancementPriorityService = EnhancementPriorityService(logger: logger)
        
        let musicLibraryService = MusicLibraryService(
            permissionService: permissionService,
            logger: logger,
            priorityService: enhancementPriorityService
        )
        
        let settingsService = SettingsService(
            logger: logger,
            artworkPersistenceService: artworkPersistenceService,
            rankHistoryService: rankHistoryService
        )
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
            appLifecycleManager: appLifecycleManager,
            settingsService: settingsService,
            enhancementPriorityService: enhancementPriorityService
        )
    }
    
    // Singleton for backward compatibility
    static let shared: DIContainer = production()
}
