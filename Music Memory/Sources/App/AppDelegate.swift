import UIKit
import MediaPlayer

class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger()
    var appState: AppState?
    private var appLifecycleManager: AppLifecycleManager?
    
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
        
        // Configure media session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            logger.log("Failed to set audio session: \(error.localizedDescription)", level: .error)
        }
        
        // Register for notifications
        registerForNotifications()
        
        // Check initial permission status
        checkPermissionStatus()
        
        // Cleanup old artwork files
        DIContainer.shared.artworkPersistenceService.cleanupOldArtwork()
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
    }
    
    private func handleAppError(_ error: AppError) {
        logger.log("App error occurred: \(error.userMessage)", level: .error)
        
        // Let the AppState handle presenting the error to the user
        DispatchQueue.main.async {
            self.appState?.setError(error)
        }
    }
}
