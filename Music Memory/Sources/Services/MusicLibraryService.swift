import Foundation
import MediaPlayer
import Combine

protocol MusicLibraryServiceProtocol {
    func requestPermission() async -> Bool
    func fetchSongs() async throws -> [Song]
    func checkPermissionStatus() async -> AppPermissionStatus
    func invalidateCache() async
    func refreshSong(withId id: String) async -> Song?
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
        
        logger.log("Fetching all songs from music library", level: .info)
        
        // Create a fresh query to get all songs
        let songsQuery = MPMediaQuery.songs()
        
        guard let mediaItems = songsQuery.items else {
            logger.log("No media items found", level: .warning)
            throw AppError.noMediaItemsFound
        }
        
        let songs = mediaItems.map { Song(from: $0) }
            .sorted(by: { $0.playCount > $1.playCount })
        
        logger.log("Fetched \(songs.count) songs from music library", level: .info)
        
        // Cache the results
        self.cachedSongs = songs
        
        return songs
    }
    
    func refreshSong(withId id: String) async -> Song? {
        guard await permissionService.checkMusicLibraryPermissionStatus() == .granted else {
            return nil
        }
        
        logger.log("Refreshing single song with ID: \(id)", level: .info)
        
        // Convert string ID back to MPMediaEntityPersistentID
        guard let persistentId = UInt64(id, radix: 16) else {
            logger.log("Invalid song ID format: \(id)", level: .error)
            return nil
        }
        
        // Create a predicate to find the specific song
        let predicate = MPMediaPropertyPredicate(
            value: persistentId,
            forProperty: MPMediaItemPropertyPersistentID
        )
        
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)
        
        // Get the updated media item
        guard let mediaItem = query.items?.first else {
            logger.log("Song not found with ID: \(id)", level: .warning)
            return nil
        }
        
        // Create updated Song object
        let updatedSong = Song(from: mediaItem)
        logger.log("Updated song: \(updatedSong.title) - Play count: \(updatedSong.playCount)", level: .info)
        
        return updatedSong
    }
    
    func invalidateCache() async {
        cachedSongs = nil
        logger.log("Music library cache invalidated", level: .info)
    }
}
