import UIKit
import MediaPlayer
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger()
    var appState: AppState?
    private var appLifecycleManager: AppLifecycleManager?
    private var cacheManagementService: CacheManagementServiceProtocol?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        setupApp()
        return true
    }
    
    private func setupApp() {
        logger.log("Application did finish launching", level: .info)
        
        // Get references from DI container
        if let appState = DIContainer.shared.appState as? AppState {
            self.appState = appState
        }
        
        // Get app lifecycle manager from DI container - it will handle artwork persistence
        self.appLifecycleManager = DIContainer.shared.appLifecycleManager
        
        // Get cache management service from DI container
        self.cacheManagementService = DIContainer.shared.cacheManagementService
        
        // Configure audio session but don't activate it immediately
        configureAudioSession()
        
        // Register for notifications
        registerForNotifications()
        
        // Check initial permission status
        checkPermissionStatus()
        
        // Perform cache management tasks
        performInitialCacheManagement()
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set up the audio session category but don't activate it yet
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            logger.log("Audio session configured successfully", level: .info)
        } catch {
            logger.log("Failed to set audio session: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func checkPermissionStatus() {
        let permissionService = DIContainer.shared.permissionService
        Task {
            let status = await permissionService.checkMusicLibraryPermissionStatus()
            if let appState = self.appState {
                DispatchQueue.main.async {
                    appState.musicLibraryPermissionStatus = status
                }
            }
        }
    }
    
    private func performInitialCacheManagement() {
        guard let cacheService = cacheManagementService else { return }
        
        // Perform cache management on a background queue to avoid blocking app launch
        DispatchQueue.global(qos: .utility).async {
            // Check if cleanup is needed
            if cacheService.shouldPerformCleanup() {
                self.logger.log("Performing initial cache cleanup on app launch", level: .info)
                cacheService.performPeriodicCleanup()
            }
            
            // Check cache health
            let healthScore = cacheService.getCacheHealthScore()
            if healthScore < 0.5 {
                self.logger.log("Cache health score is low (\(healthScore)). Consider cleanup.", level: .warning)
                
                // If health is very poor, perform emergency cleanup
                if healthScore < 0.2 {
                    self.logger.log("Performing emergency cache cleanup due to poor health", level: .error)
                    cacheService.performFullCleanup()
                }
            } else {
                self.logger.log("Cache health score: \(healthScore)", level: .info)
            }
            
            // Log cache statistics for debugging
            let stats = cacheService.getCacheStatistics()
            self.logger.log("Cache stats - Keys: \(stats.totalUserDefaultsKeys), Size: \(stats.totalDataSize)", level: .info)
        }
    }
    
    private func registerForNotifications() {
        // Handle errors posted through NotificationCenter
        NotificationCenter.default.addObserver(
            forName: .appErrorOccurred,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let error = notification.object as? AppError else { return }
            self?.handleAppError(error)
        }
        
        // Handle memory warnings to trigger cache cleanup
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: OperationQueue()
        ) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.handleMemoryWarning()
            }
        }
        
        // Handle app entering background to perform cleanup
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: OperationQueue()
        ) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.handleAppEnteredBackground()
            }
        }
    }
    
    private func handleAppError(_ error: AppError) {
        logger.log("App error occurred: \(error.userMessage)", level: .error)
        
        // Let the AppState handle presenting the error to the user
        DispatchQueue.main.async {
            self.appState?.setError(error)
        }
    }
    
    private func handleMemoryWarning() {
        logger.log("Memory warning received - performing cache cleanup", level: .warning)
        
        // Perform emergency cleanup to free memory
        cacheManagementService?.performFullCleanup()
        
        // Also clear any in-memory caches if available
        if let musicLibraryService = DIContainer.shared.musicLibraryService as? MusicLibraryService {
            Task {
                await musicLibraryService.clearMusicKitSearchCache()
            }
        }
    }
    
    private func handleAppEnteredBackground() {
        logger.log("App entered background - performing maintenance", level: .info)
        
        // Perform background cleanup if needed
        if let cacheService = cacheManagementService,
           cacheService.shouldPerformCleanup() {
            cacheService.performPeriodicCleanup()
        }
    }
    
    // MARK: - Application Lifecycle Methods
    
    func applicationWillTerminate(_ application: UIApplication) {
        logger.log("Application will terminate - performing final cleanup", level: .info)
        
        // Perform final cache cleanup on app termination
        if let cacheService = cacheManagementService {
            // Quick cleanup to ensure data integrity
            let stats = cacheService.getCacheStatistics()
            logger.log("Final cache stats - Keys: \(stats.totalUserDefaultsKeys), Size: \(stats.totalDataSize)", level: .info)
            
            // Only perform emergency cleanup if absolutely necessary
            if stats.totalUserDefaultsKeys > 10000 {
                logger.log("Performing emergency cleanup on app termination", level: .warning)
                cacheService.performFullCleanup()
            }
        }
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        handleMemoryWarning()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // This is called by the notification observer, but we can also handle it here
        logger.log("Application entered background", level: .debug)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.log("Application will enter foreground", level: .debug)
        
        // Check if we need to perform cleanup after being in background
        DispatchQueue.global(qos: .utility).async {
            if let cacheService = self.cacheManagementService,
               cacheService.shouldPerformCleanup() {
                self.logger.log("Performing foreground cache cleanup", level: .info)
                cacheService.performPeriodicCleanup()
            }
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.log("Application became active", level: .debug)
        
        // Check cache health when app becomes active
        DispatchQueue.global(qos: .utility).async {
            if let cacheService = self.cacheManagementService {
                let healthScore = cacheService.getCacheHealthScore()
                if healthScore < 0.3 {
                    self.logger.log("Cache health degraded while inactive (score: \(healthScore))", level: .warning)
                }
            }
        }
    }
}

// MARK: - Cache Management Extensions

extension AppDelegate {
    /// Get current cache statistics for debugging
    func getCurrentCacheStatistics() -> CacheStatistics? {
        return cacheManagementService?.getCacheStatistics()
    }
    
    /// Force a cache cleanup (useful for debugging)
    func forceCacheCleanup() {
        logger.log("Force cache cleanup requested", level: .info)
        cacheManagementService?.performPeriodicCleanup()
    }
    
    /// Get cache optimization recommendations
    func getCacheRecommendations() -> [String] {
        return cacheManagementService?.getCacheOptimizationRecommendations() ?? []
    }
    
    /// Check if cache cleanup is needed
    func isCacheCleanupNeeded() -> Bool {
        return cacheManagementService?.shouldPerformCleanup() ?? false
    }
}
