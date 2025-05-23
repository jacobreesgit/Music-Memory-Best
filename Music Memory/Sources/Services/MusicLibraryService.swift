import Foundation
import MediaPlayer
import Combine

protocol MusicLibraryServiceProtocol {
    func requestPermission() async -> Bool
    func fetchSongs() async throws -> [Song]
    func checkPermissionStatus() async -> AppPermissionStatus
    func invalidateCache() async
}

actor MusicLibraryService: MusicLibraryServiceProtocol {
    private let permissionService: PermissionServiceProtocol
    private let logger: LoggerProtocol
    private var cachedSongs: [Song]?
    private var cancellables = Set<AnyCancellable>()
    private var lastRefreshTime: Date = .distantPast
    private var refreshDebounceInterval: TimeInterval = 2.0
    
    // Track the current playing item to detect actual changes
    private var currentPlayingItem: MPMediaItem?
    
    init(permissionService: PermissionServiceProtocol, logger: LoggerProtocol) {
        self.permissionService = permissionService
        self.logger = logger
        
        // Setup observers after initialization
        Task {
            await setupObservers()
        }
    }
    
    private func setupObservers() async {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Begin generating notifications
        MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        // Create a local cancellables set that we'll manage
        var localCancellables = Set<AnyCancellable>()
        
        // Use Combine for cleaner observer management
        await MainActor.run {
            // Media library changes
            NotificationCenter.default.publisher(for: .MPMediaLibraryDidChange)
                .debounce(for: .seconds(1), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    Task {
                        await self?.handleMediaLibraryChange()
                    }
                }
                .store(in: &localCancellables)
            
            // Now playing item changes
            NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
                .sink { [weak self] _ in
                    Task {
                        await self?.handleNowPlayingItemChange()
                    }
                }
                .store(in: &localCancellables)
            
            // Playback state changes
            NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)
                .sink { [weak self] _ in
                    Task {
                        await self?.handlePlaybackStateChange()
                    }
                }
                .store(in: &localCancellables)
        }
        
        // Now store the cancellables in our actor's property
        self.cancellables = localCancellables
    }
    
    private func handleMediaLibraryChange() async {
        logger.log("Media library change detected", level: .info)
        await refreshIfNeeded()
    }
    
    private func handleNowPlayingItemChange() async {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        let newItem = musicPlayer.nowPlayingItem
        
        // Check if this is an actual track change
        if let previousItem = currentPlayingItem,
           let newItem = newItem,
           previousItem.persistentID != newItem.persistentID {
            
            logger.log("Track changed from \(previousItem.title ?? "Unknown") to \(newItem.title ?? "Unknown")", level: .info)
            
            // Wait a bit for the system to update play counts
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            logger.log("Refreshing library after track change", level: .info)
            // Force refresh without debouncing for track changes
            await forceRefresh()
        }
        
        currentPlayingItem = newItem
    }
    
    private func handlePlaybackStateChange() async {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        let state = musicPlayer.playbackState
        
        let stateString: String
        switch state {
        case .stopped: stateString = "stopped"
        case .playing: stateString = "playing"
        case .paused: stateString = "paused"
        case .interrupted: stateString = "interrupted"
        case .seekingForward: stateString = "seekingForward"
        case .seekingBackward: stateString = "seekingBackward"
        @unknown default: stateString = "unknown"
        }
        
        logger.log("Playback state changed to: \(stateString)", level: .info)
        
        // Only refresh on stop/pause if we have a current item (indicates playback was active)
        if (state == .stopped || state == .paused) && currentPlayingItem != nil {
            logger.log("Triggering refresh due to playback \(stateString)", level: .info)
            await refreshIfNeeded()
        }
    }
    
    private func refreshIfNeeded() async {
        let now = Date()
        guard now.timeIntervalSince(lastRefreshTime) >= refreshDebounceInterval else {
            logger.log("Skipping refresh due to debounce (last refresh was \(String(format: "%.1f", now.timeIntervalSince(lastRefreshTime)))s ago, need \(refreshDebounceInterval)s)", level: .info)
            return
        }
        
        logger.log("Proceeding with library refresh", level: .info)
        await forceRefresh()
    }
    
    private func forceRefresh() async {
        lastRefreshTime = Date()
        logger.log("Force refreshing library (bypassing debounce)", level: .info)
        await invalidateCache()
    }
    
    func requestPermission() async -> Bool {
        return await permissionService.requestMusicLibraryPermission()
    }
    
    func checkPermissionStatus() async -> AppPermissionStatus {
        return await permissionService.checkMusicLibraryPermissionStatus()
    }
    
    func fetchSongs() async throws -> [Song] {
        guard await permissionService.checkMusicLibraryPermissionStatus() == .granted else {
            throw AppError.permissionDenied
        }
        
        // Return cached songs if available
        if let cachedSongs = cachedSongs {
            logger.log("Returning \(cachedSongs.count) cached songs", level: .debug)
            return cachedSongs
        }
        
        // Fetch fresh data
        do {
            let songsQuery = MPMediaQuery.songs()
            guard let mediaItems = songsQuery.items else {
                throw AppError.noMediaItemsFound
            }
            
            let songs = mediaItems.map { Song(from: $0) }
                .sorted(by: { $0.playCount > $1.playCount })
            
            self.cachedSongs = songs
            logger.log("Fetched \(songs.count) songs from music library", level: .info)
            return songs
        } catch {
            logger.log("Failed to fetch songs: \(error.localizedDescription)", level: .error)
            throw AppError.failedToFetchSongs(underlyingError: error)
        }
    }
    
    func invalidateCache() async {
        cachedSongs = nil
        logger.log("Music library cache invalidated", level: .info)
        
        // Notify observers that the media library has changed
        await MainActor.run {
            NotificationCenter.default.post(name: .mediaLibraryChanged, object: nil)
        }
    }
    
    deinit {
        // Clean up
        MPMediaLibrary.default().endGeneratingLibraryChangeNotifications()
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
        cancellables.removeAll()
    }
}
