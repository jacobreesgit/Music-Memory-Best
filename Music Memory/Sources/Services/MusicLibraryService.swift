import Foundation
import MediaPlayer

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
    private var mediaLibraryQueryTask: Task<Void, Never>?
    private var playbackObserverTask: Task<Void, Never>?
    private var nowPlayingObserverTask: Task<Void, Never>?
    private var lastInvalidationTime: Date = .distantPast
    
    init(permissionService: PermissionServiceProtocol, logger: LoggerProtocol) {
        self.permissionService = permissionService
        self.logger = logger
        
        // Schedule the setup to run after initialization
        // This is a special Task that's tied to the actor's lifetime
        Task {
            await setupMediaLibraryObserver()
            await setupPlaybackObservers()
        }
    }
    
    private func setupMediaLibraryObserver() async {
        // Begin listening for media library changes
        MPMediaLibrary.default().beginGeneratingLibraryChangeNotifications()
        
        // Create a task to observe the notifications
        mediaLibraryQueryTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await _ in NotificationCenter.default.notifications(named: .MPMediaLibraryDidChange) {
                await self.handleMediaLibraryChange()
            }
        }
    }
    
    private func setupPlaybackObservers() async {
        // Set up playback notifications
        MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()
        
        // Observe playback state changes with debounce protection
        playbackObserverTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await _ in NotificationCenter.default.notifications(named: .MPMusicPlayerControllerPlaybackStateDidChange) {
                if await self.shouldProcessStateChange() {
                    let musicPlayer = MPMusicPlayerController.systemMusicPlayer
                    if musicPlayer.playbackState == .stopped || musicPlayer.playbackState == .paused {
                        await self.logger.log("Playback stopped/paused - refreshing media library", level: .info)
                        await self.invalidateCache()
                    }
                }
            }
        }
        
        // Observe now playing item changes
        nowPlayingObserverTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await _ in NotificationCenter.default.notifications(named: .MPMusicPlayerControllerNowPlayingItemDidChange) {
                if await self.shouldProcessStateChange() {
                    // Add a small delay to allow the play count to update
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
                    await self.logger.log("Now playing item changed - refreshing media library", level: .info)
                    await self.invalidateCache()
                }
            }
        }
    }
    
    // Check if we should process this state change (basic debouncing)
    private func shouldProcessStateChange() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastInvalidationTime) < 3.0 {
            logger.log("Debouncing library refresh", level: .info)
            return false
        }
        return true
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
        
        do {
            if let cachedSongs = cachedSongs {
                return cachedSongs
            }
            
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
        lastInvalidationTime = Date()
        cachedSongs = nil
        logger.log("Music library cache invalidated", level: .info)
        
        // Notify observers that the media library has changed
        Task { @MainActor in
            NotificationCenter.default.post(name: .mediaLibraryChanged, object: nil)
        }
    }
    
    private func handleMediaLibraryChange() async {
        if shouldProcessStateChange() {
            logger.log("Media library change detected", level: .info)
            await invalidateCache()
        }
    }
    
    deinit {
        // Cancel all observer tasks when this service is deallocated
        mediaLibraryQueryTask?.cancel()
        playbackObserverTask?.cancel()
        nowPlayingObserverTask?.cancel()
        
        MPMediaLibrary.default().endGeneratingLibraryChangeNotifications()
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
    }
}
