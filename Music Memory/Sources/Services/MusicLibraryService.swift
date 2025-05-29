import Foundation
import MediaPlayer
import MusicKit
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
        // Request both MediaPlayer and MusicKit permissions
        let mediaPlayerGranted = await permissionService.requestMusicLibraryPermission()
        let musicKitGranted = await requestMusicKitPermission()
        
        // MediaPlayer permission is required, MusicKit is enhancement
        if mediaPlayerGranted {
            if !musicKitGranted {
                logger.log("MusicKit permission not granted - will use MediaPlayer only", level: .info)
            } else {
                logger.log("Both MediaPlayer and MusicKit permissions granted", level: .info)
            }
            return true
        }
        
        return false
    }
    
    func checkPermissionStatus() async -> AppPermissionStatus {
        return await permissionService.checkMusicLibraryPermissionStatus()
    }
    
    func fetchSongs() async throws -> [Song] {
        guard await permissionService.checkMusicLibraryPermissionStatus() == .granted else {
            throw AppError.permissionDenied
        }
        
        logger.log("Fetching songs with MediaPlayer (MusicKit integration ready for future enhancement)", level: .info)
        
        // For now, use MediaPlayer as the primary source
        // MusicKit integration can be enhanced in future iterations
        let songs = try await fetchMediaPlayerSongs()
        
        // Log MusicKit status for future enhancement
        let musicKitStatus = MusicAuthorization.currentStatus
        logger.log("MusicKit status: \(musicKitStatus) - Ready for future artwork enhancement", level: .info)
        
        return songs
    }
    
    // MARK: - Private Methods
    
    private func requestMusicKitPermission() async -> Bool {
        let status = await MusicAuthorization.request()
        let granted = status == .authorized
        logger.log("MusicKit permission status: \(status)", level: .info)
        return granted
    }
    
    private func fetchMediaPlayerSongs() async throws -> [Song] {
        // Create a query to get all songs
        let songsQuery = MPMediaQuery.songs()
        
        guard let mediaItems = songsQuery.items else {
            logger.log("No media items found", level: .warning)
            throw AppError.noMediaItemsFound
        }
        
        // Convert to Song objects - MusicKit enhancement will be added in future iterations
        let songs = mediaItems.map { mediaItem in
            // For now, create songs without MusicKit data
            // This preserves all existing functionality while laying groundwork for enhancement
            return Song(from: mediaItem, musicKitTrack: nil)
        }
        
        logger.log("Fetched \(songs.count) songs from MediaPlayer", level: .info)
        
        return songs
    }
}
