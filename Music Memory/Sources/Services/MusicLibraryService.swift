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
        
        logger.log("Fetching songs with hybrid MediaPlayer + MusicKit approach", level: .info)
        
        // First, get songs from MediaPlayer (our base data source)
        let mediaPlayerSongs = try await fetchMediaPlayerSongs()
        
        // Then, enhance with MusicKit data if available
        let enhancedSongs = await enhanceWithMusicKit(songs: mediaPlayerSongs)
        
        logger.log("Fetched \(enhancedSongs.count) songs (\(enhancedSongs.filter { $0.hasEnhancedData }.count) with MusicKit enhancements)", level: .info)
        
        return enhancedSongs
    }
    
    // MARK: - Private Methods
    
    private func requestMusicKitPermission() async -> Bool {
        do {
            let status = await MusicAuthorization.request()
            let granted = status == .authorized
            logger.log("MusicKit permission status: \(status)", level: .info)
            return granted
        } catch {
            logger.log("Failed to request MusicKit permission: \(error.localizedDescription)", level: .error)
            return false
        }
    }
    
    private func fetchMediaPlayerSongs() async throws -> [Song] {
        // Create a query to get all songs
        let songsQuery = MPMediaQuery.songs()
        
        guard let mediaItems = songsQuery.items else {
            logger.log("No media items found", level: .warning)
            throw AppError.noMediaItemsFound
        }
        
        // Convert to Song objects (without MusicKit enhancements yet)
        let songs = mediaItems.map { Song(from: $0) }
        
        logger.log("Fetched \(songs.count) songs from MediaPlayer", level: .info)
        
        return songs
    }
    
    private func enhanceWithMusicKit(songs: [Song]) async -> [Song] {
        // Check if MusicKit is available
        guard await MusicAuthorization.currentStatus == .authorized else {
            logger.log("MusicKit not authorized - returning songs without enhancements", level: .info)
            return songs
        }
        
        do {
            // Create a batch request to enhance songs with MusicKit data
            var enhancedSongs: [Song] = []
            
            // Process songs in batches to avoid overwhelming the API
            let batchSize = 25
            let batches = songs.chunked(into: batchSize)
            
            for batch in batches {
                let batchEnhanced = await enhanceSongBatch(batch)
                enhancedSongs.append(contentsOf: batchEnhanced)
            }
            
            let enhancedCount = enhancedSongs.filter { $0.hasEnhancedData }.count
            logger.log("Enhanced \(enhancedCount) of \(songs.count) songs with MusicKit data", level: .info)
            
            return enhancedSongs
            
        } catch {
            logger.log("Failed to enhance songs with MusicKit: \(error.localizedDescription)", level: .warning)
            return songs // Return original songs if enhancement fails
        }
    }
    
    private func enhanceSongBatch(_ songs: [Song]) async -> [Song] {
        // Try to match songs with MusicKit tracks by searching
        var enhancedSongs: [Song] = []
        
        for song in songs {
            do {
                // Search for the track in MusicKit
                let searchTerm = "\(song.title) \(song.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
                
                var searchRequest = MusicSearchRequest(term: searchTerm, types: [Track.self])
                searchRequest.limit = 3 // Get top 3 results for better matching
                
                let searchResponse = try await searchRequest.response()
                
                // Find the best matching track
                if let matchingTrack = findBestMatch(for: song, in: searchResponse.tracks) {
                    // Create enhanced song with MusicKit data
                    let enhancedSong = Song(from: song.mediaItem, musicKitTrack: matchingTrack)
                    enhancedSongs.append(enhancedSong)
                } else {
                    // No match found, keep original song
                    enhancedSongs.append(song)
                }
                
                // Small delay to be respectful to the API
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                
            } catch {
                // If search fails for this song, keep the original
                logger.log("Failed to enhance song '\(song.title)': \(error.localizedDescription)", level: .debug)
                enhancedSongs.append(song)
            }
        }
        
        return enhancedSongs
    }
    
    private func findBestMatch(for song: Song, in tracks: MusicItemCollection<Track>) -> Track? {
        guard !tracks.isEmpty else { return nil }
        
        let songTitle = song.title.lowercased()
        let songArtist = song.artist.lowercased()
        
        // Score each track and return the best match
        let scoredTracks = tracks.compactMap { track -> (Track, Double)? in
            guard let trackTitle = track.title?.lowercased(),
                  let trackArtist = track.artistName?.lowercased() else {
                return nil
            }
            
            // Calculate similarity scores
            let titleScore = stringSimilarity(songTitle, trackTitle)
            let artistScore = stringSimilarity(songArtist, trackArtist)
            
            // Weighted score (title is more important)
            let totalScore = (titleScore * 0.7) + (artistScore * 0.3)
            
            return (track, totalScore)
        }
        
        // Return the track with the highest score if it's above threshold
        let bestMatch = scoredTracks.max { $0.1 < $1.1 }
        if let match = bestMatch, match.1 > 0.8 { // 80% similarity threshold
            return match.0
        }
        
        return nil
    }
    
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        // Simple similarity calculation using Levenshtein distance
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        return maxLength == 0 ? 1.0 : 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let aLen = a.count
        let bLen = b.count
        
        if aLen == 0 { return bLen }
        if bLen == 0 { return aLen }
        
        var matrix = Array(repeating: Array(repeating: 0, count: bLen + 1), count: aLen + 1)
        
        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }
        
        for i in 1...aLen {
            for j in 1...bLen {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[aLen][bLen]
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
