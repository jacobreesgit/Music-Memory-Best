import Foundation
import MusicKit
import MediaPlayer
import Combine

// MARK: - Music Manager
class MusicManager: ObservableObject {
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var isMonitoring = false
    
    private var dataManager: DataManager
    private var playbackTimer: Timer?
    private var lastKnownItem: MPMediaItem?
    private var lastKnownPosition: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    
    init(dataManager: DataManager = DataManager()) {
        self.dataManager = dataManager
        setupNotifications()
    }
    
    // MARK: - Authorization
    func requestMusicAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.authorizationStatus = status
        }
    }
    
    func requestMediaLibraryAuthorization() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.mediaLibraryStatus = status
            }
        }
    }
    
    // MARK: - Setup Notifications
    private func setupNotifications() {
        // Register for playback notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: MPMusicPlayerController.systemMusicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: MPMusicPlayerController.systemMusicPlayer
        )
        
        // Begin receiving remote control events
        MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    // MARK: - Playback Monitoring
    func startPlaybackMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start timer to check playback position every 0.5 seconds
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePlaybackPosition()
        }
        
        print("Started playback monitoring")
    }
    
    func stopPlaybackMonitoring() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isMonitoring = false
        print("Stopped playback monitoring")
    }
    
    // MARK: - Position Monitoring
    private func updatePlaybackPosition() {
        let player = MPMusicPlayerController.systemMusicPlayer
        let currentItem = player.nowPlayingItem
        let currentPosition = player.currentPlaybackTime
        
        // Store current position for completion detection
        if currentItem != nil {
            lastKnownPosition = currentPosition
        }
    }
    
    // MARK: - Now Playing Item Changed
    @objc private func nowPlayingItemChanged() {
        let player = MPMusicPlayerController.systemMusicPlayer
        let currentItem = player.nowPlayingItem
        
        // Check if previous song ended naturally
        if let previousItem = lastKnownItem {
            checkSongCompletion(for: previousItem)
        }
        
        // Update tracking
        lastKnownItem = currentItem
        lastKnownPosition = 0
        
        if currentItem != nil {
            print("Now playing: \(currentItem?.title ?? "Unknown") by \(currentItem?.artist ?? "Unknown")")
        }
    }
    
    // MARK: - Playback State Changed
    @objc private func playbackStateChanged() {
        let player = MPMusicPlayerController.systemMusicPlayer
        
        switch player.playbackState {
        case .playing:
            if !isMonitoring {
                startPlaybackMonitoring()
            }
        case .paused, .stopped:
            // Don't stop monitoring immediately - song might resume
            break
        default:
            break
        }
    }
    
    // MARK: - Song Completion Detection
    private func checkSongCompletion(for item: MPMediaItem) {
        let duration = item.playbackDuration
        guard duration > 0 else { return }
        
        // Check if song ended naturally (within 5 seconds of end)
        let completionThreshold: TimeInterval = 5.0
        let timeDifference = duration - lastKnownPosition
        
        if timeDifference <= completionThreshold {
            // Song completed naturally
            let completionPercentage = min(lastKnownPosition / duration, 1.0)
            
            // Only count if significantly played (>50% completion)
            if completionPercentage > 0.5 {
                recordSongPlay(item: item, playDuration: lastKnownPosition, completionPercentage: completionPercentage)
            }
        }
    }
    
    // MARK: - Record Song Play
    private func recordSongPlay(item: MPMediaItem, playDuration: TimeInterval, completionPercentage: Double) {
        // Extract identifiers and metadata
        let songID = item.persistentID.description
        let albumID = item.albumPersistentID.description
        let artistID = item.artistPersistentID.description
        
        // Record the play
        dataManager.recordSongCompletion(
            songID: songID,
            albumID: albumID,
            artistID: artistID,
            playDuration: playDuration,
            completionPercentage: completionPercentage,
            source: "Local"
        )
        
        // Update local play count for immediate UI updates
        updateLocalPlayCount(for: songID)
        
        print("Recorded song completion: \(item.title ?? "Unknown") (\(Int(completionPercentage * 100))% completed)")
    }
    
    // MARK: - Dual Tracking System
    private func updateLocalPlayCount(for songID: String) {
        let key = "localPlayCount_\(songID)"
        let currentCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
    }
    
    func getDisplayedPlayCount(for item: MPMediaItem) -> Int {
        let songID = item.persistentID.description
        let systemPlayCount = Int(item.playCount)
        let localPlayCount = UserDefaults.standard.integer(forKey: "localPlayCount_\(songID)")
        return systemPlayCount + localPlayCount
    }
    
    // MARK: - Cleanup
    deinit {
        stopPlaybackMonitoring()
        NotificationCenter.default.removeObserver(self)
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
    }
}
