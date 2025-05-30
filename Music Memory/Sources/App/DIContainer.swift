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
    let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    let appLifecycleManager: AppLifecycleManager
    let settingsService: SettingsServiceProtocol
    let enhancementPriorityService: EnhancementPriorityServiceProtocol
    let cacheManagementService: CacheManagementServiceProtocol
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        permissionService: PermissionServiceProtocol,
        logger: LoggerProtocol,
        appState: any AppStateProtocol,
        navigationManager: NavigationManager,
        rankHistoryService: RankHistoryServiceProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol,
        enhancedSongCacheService: EnhancedSongCacheServiceProtocol,
        appLifecycleManager: AppLifecycleManager,
        settingsService: SettingsServiceProtocol,
        enhancementPriorityService: EnhancementPriorityServiceProtocol,
        cacheManagementService: CacheManagementServiceProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.permissionService = permissionService
        self.logger = logger
        self.appState = appState
        self.navigationManager = navigationManager
        self.rankHistoryService = rankHistoryService
        self.artworkPersistenceService = artworkPersistenceService
        self.enhancedSongCacheService = enhancedSongCacheService
        self.appLifecycleManager = appLifecycleManager
        self.settingsService = settingsService
        self.enhancementPriorityService = enhancementPriorityService
        self.cacheManagementService = cacheManagementService
    }
    
    // Factory method for production with proper dependency injection
    static func production() -> DIContainer {
        let logger = Logger()
        let permissionService = PermissionService()
        let rankHistoryService = RankHistoryService(logger: logger)
        let artworkPersistenceService = ArtworkPersistenceService(logger: logger)
        let enhancedSongCacheService = EnhancedSongCacheService(logger: logger)
        let enhancementPriorityService = EnhancementPriorityService(logger: logger)
        
        // CRITICAL FIX: Inject cache services into MusicLibraryService
        let musicLibraryService = MusicLibraryService(
            permissionService: permissionService,
            logger: logger,
            priorityService: enhancementPriorityService,
            enhancedSongCacheService: enhancedSongCacheService,
            artworkPersistenceService: artworkPersistenceService
        )
        
        let cacheManagementService = CacheManagementService(
            logger: logger,
            rankHistoryService: rankHistoryService,
            artworkPersistenceService: artworkPersistenceService,
            enhancedSongCacheService: enhancedSongCacheService,
            musicLibraryService: musicLibraryService
        )
        
        let settingsService = SettingsService(
            logger: logger,
            artworkPersistenceService: artworkPersistenceService,
            rankHistoryService: rankHistoryService,
            enhancedSongCacheService: enhancedSongCacheService
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
            enhancedSongCacheService: enhancedSongCacheService,
            appLifecycleManager: appLifecycleManager,
            settingsService: settingsService,
            enhancementPriorityService: enhancementPriorityService,
            cacheManagementService: cacheManagementService
        )
    }
    
    // Singleton for backward compatibility
    static let shared: DIContainer = production()
}
