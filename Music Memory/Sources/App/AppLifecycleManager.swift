import SwiftUI
import Combine

/// Manages app lifecycle events and coordinates artwork persistence
class AppLifecycleManager: ObservableObject {
    private let logger: LoggerProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(logger: LoggerProtocol, artworkPersistenceService: ArtworkPersistenceServiceProtocol) {
        self.logger = logger
        self.artworkPersistenceService = artworkPersistenceService
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        // Listen for app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidEnterBackground() {
        logger.log("App entered background - saving artwork if needed", level: .info)
        saveCurrentArtworkIfNeeded()
    }
    
    private func handleAppWillTerminate() {
        logger.log("App will terminate - saving artwork if needed", level: .info)
        saveCurrentArtworkIfNeeded()
    }
    
    private func handleAppDidBecomeActive() {
        logger.log("App became active - checking for artwork restoration", level: .info)
        // Trigger artwork restoration check in NowPlayingViewModel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NowPlayingViewModel.shared.checkForArtworkRestoration()
        }
    }
    
    private func saveCurrentArtworkIfNeeded() {
        let nowPlayingViewModel = NowPlayingViewModel.shared
        
        // Check if there's a currently playing song with artwork
        if let currentSong = nowPlayingViewModel.currentSong,
           let currentImage = nowPlayingViewModel.currentImage {
            
            logger.log("Saving artwork for currently playing song: '\(currentSong.title)'", level: .info)
            artworkPersistenceService.saveCurrentArtwork(songId: currentSong.id, artwork: currentImage)
        } else {
            logger.log("No current song or artwork to save", level: .debug)
        }
    }
}
