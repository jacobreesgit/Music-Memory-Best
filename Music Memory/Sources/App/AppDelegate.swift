import UIKit
import MediaPlayer

class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        setupApp()
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Invalidate caches when app comes back to foreground
        // as media library might have changed
        if let musicLibraryService = DIContainer.shared.musicLibraryService as? MusicLibraryService {
            Task {
                await musicLibraryService.invalidateCache()
            }
        }
    }
    
    private func setupApp() {
        logger.log("Application did finish launching", level: .info)
        
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
        
        // Handle media library notifications
        NotificationCenter.default.addObserver(
            forName: .MPMediaLibraryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaLibraryChange()
        }
    }
    
    private func handleAppError(_ error: AppError) {
        logger.log("App error occurred: \(error.userMessage)", level: .error)
        
        // Let the AppState handle presenting the error to the user
        DispatchQueue.main.async {
            if let appState = DIContainer.shared.appState as? AppState {
                appState.setError(error)
            }
        }
    }
    
    private func handleMediaLibraryChange() {
        logger.log("Media library changed", level: .info)
        
        // Invalidate caches when media library changes
        if let musicLibraryService = DIContainer.shared.musicLibraryService as? MusicLibraryService {
            Task {
                await musicLibraryService.invalidateCache()
                // Post notification that others can observe
                NotificationCenter.default.post(name: .mediaLibraryChanged, object: nil)
            }
        }
    }
}

extension NSNotification.Name {
    static let mediaLibraryChanged = NSNotification.Name("mediaLibraryChanged")
}
