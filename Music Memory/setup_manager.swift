import Foundation
import MusicKit
import MediaPlayer
import Combine

// MARK: - Setup Manager
class SetupManager: ObservableObject {
    @Published var isSetupComplete = false
    @Published var setupStatus = "Initializing..."
    @Published var hasAppleMusic = false
    @Published var hasMediaLibraryAccess = false
    
    private let musicManager: MusicManager
    private let dataManager: DataManager
    private var cancellables = Set<AnyCancellable>()
    
    init(musicManager: MusicManager = MusicManager(), dataManager: DataManager = DataManager()) {
        self.musicManager = musicManager
        self.dataManager = dataManager
        
        setupBindings()
    }
    
    // MARK: - Setup Bindings
    private func setupBindings() {
        // Monitor authorization status changes
        musicManager.$authorizationStatus
            .sink { [weak self] status in
                self?.hasAppleMusic = (status == .authorized)
                self?.updateSetupStatus()
            }
            .store(in: &cancellables)
        
        musicManager.$mediaLibraryStatus
            .sink { [weak self] status in
                self?.hasMediaLibraryAccess = (status == .authorized)
                self?.updateSetupStatus()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main Setup Process
    func performSetup() async {
        await MainActor.run {
            setupStatus = "Setting up Core Data..."
        }
        
        // Initialize Core Data (already done via PersistenceController)
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for UX
        } catch {
            print("Sleep interrupted: \(error)")
        }
        
        await MainActor.run {
            setupStatus = "Requesting Music permissions..."
        }
        
        // Request MusicKit authorization
        await musicManager.requestMusicAuthorization()
        
        // Request MediaPlayer library access
        await MainActor.run {
            musicManager.requestMediaLibraryAuthorization()
        }
        
        // Wait a moment for MediaPlayer authorization
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } catch {
            print("Sleep interrupted: \(error)")
        }
        
        await MainActor.run {
            setupStatus = "Setting up playback monitoring..."
        }
        
        // Setup playback monitoring if we have permissions
        if hasMediaLibraryAccess {
            musicManager.startPlaybackMonitoring()
        }
        
        await MainActor.run {
            setupStatus = "Setup complete!"
            isSetupComplete = true
        }
        
        print("Music Memory setup completed")
        print("Apple Music access: \(hasAppleMusic)")
        print("Media Library access: \(hasMediaLibraryAccess)")
    }
    
    // MARK: - Update Setup Status
    private func updateSetupStatus() {
        if isSetupComplete {
            return
        }
        
        switch (hasAppleMusic, hasMediaLibraryAccess) {
        case (true, true):
            setupStatus = "Full access granted - tracking all music"
        case (false, true):
            setupStatus = "Local library access only"
        case (true, false):
            setupStatus = "Apple Music access granted"
        case (false, false):
            setupStatus = "Limited functionality - please grant permissions"
        }
    }
    
    // MARK: - Graceful Degradation Handling
    func getAvailableFeatures() -> [String] {
        var features: [String] = []
        
        if hasAppleMusic {
            features.append("Apple Music streaming history")
            features.append("Apple Music catalog access")
        }
        
        if hasMediaLibraryAccess {
            features.append("Local library tracking")
            features.append("Play count monitoring")
        }
        
        if hasAppleMusic || hasMediaLibraryAccess {
            features.append("Personal Hot 100 charts")
            features.append("Listening analytics")
        }
        
        return features
    }
    
    func getDataSourceDescription() -> String {
        switch (hasAppleMusic, hasMediaLibraryAccess) {
        case (true, true):
            return "Tracking music from Apple Music and your local library"
        case (false, true):
            return "Tracking music from your local library only"
        case (true, false):
            return "Tracking Apple Music streaming only"
        case (false, false):
            return "No music tracking available - please enable permissions in Settings"
        }
    }
}
