import Foundation
import MediaPlayer
import Combine

protocol MusicLibraryServiceProtocol {
    func requestPermission() async -> Bool
    func fetchSongs() async throws -> [Song]
    func checkPermissionStatus() async -> AppPermissionStatus
}

actor MusicLibraryService: MusicLibraryServiceProtocol {
    private let permissionService: PermissionServiceProtocol
    private let logger: LoggerProtocol
    
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
        
        // Create a query to get all songs
        let songsQuery = MPMediaQuery.songs()
        
        guard let mediaItems = songsQuery.items else {
            logger.log("No media items found", level: .warning)
            throw AppError.noMediaItemsFound
        }
        
        let songs = mediaItems.map { Song(from: $0) }
            .sorted(by: { $0.playCount > $1.playCount })
        
        logger.log("Fetched \(songs.count) songs from music library", level: .info)
        
        return songs
    }
}
