import Foundation
import MediaPlayer

protocol MusicLibraryServiceProtocol {
    func requestPermission() async -> Bool
    func fetchSongs() async throws -> [Song]
    func checkPermissionStatus() async -> AppPermissionStatus
}

actor MusicLibraryService: MusicLibraryServiceProtocol {
    private let permissionService: PermissionServiceProtocol
    private let logger: LoggerProtocol
    private var cachedSongs: [Song]?
    
    init(permissionService: PermissionServiceProtocol, logger: LoggerProtocol) {
        self.permissionService = permissionService
        self.logger = logger
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
    
    func invalidateCache() {
        cachedSongs = nil
    }
    
    func setupNowPlayingObserver() {
        Task {
            for await _ in NotificationCenter.default.notifications(named: .nowPlayingItemChanged) {
                // Song changed - invalidate cache to refresh library
                invalidateCache()
                logger.log("Refreshing music library after song change", level: .info)
            }
        }
    }
}
