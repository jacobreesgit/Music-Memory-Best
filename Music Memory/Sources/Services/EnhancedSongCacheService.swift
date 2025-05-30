import Foundation
import MusicKit

protocol EnhancedSongCacheServiceProtocol {
    func cacheEnhancedSong(_ song: Song)
    func getCachedEnhancedSong(for songId: String) -> Song?
    func isSongEnhanced(_ songId: String) -> Bool
    func clearEnhancedSongCache()
    func cleanupOldEnhancedSongs()
    func getEnhancedSongCacheSize() -> String
}

/// Cache metadata for tracking enhanced songs
struct EnhancedSongMetadata: Codable {
    let songId: String
    let timestamp: Date
    let hasEnhancedData: Bool
}

/// Simplified cached song data to avoid complex serialization
struct CachedSongData: Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let playCount: Int
    
    // Enhanced metadata from MusicKit
    let enhancedGenre: String?
    let enhancedDuration: TimeInterval?
    let enhancedArtist: String?
    let enhancedAlbum: String?
    let enhancedReleaseDate: Date?
    let enhancedComposer: String?
    let enhancedTrackNumber: Int?
    let enhancedDiscNumber: Int?
    let isExplicit: Bool
    let hasEnhancedData: Bool
    
    // Artwork URL (we'll cache the URL, not the image data)
    let artworkURL: String?
}

class EnhancedSongCacheService: EnhancedSongCacheServiceProtocol {
    private let logger: LoggerProtocol
    private let userDefaults = UserDefaults.standard
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxCachedSongs = 1000 // Limit to prevent UserDefaults bloat
    
    init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    func cacheEnhancedSong(_ song: Song) {
        let cachedData = CachedSongData(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            playCount: song.playCount,
            enhancedGenre: song.hasEnhancedData ? song.enhancedGenre : nil,
            enhancedDuration: song.hasEnhancedData ? song.enhancedDuration : nil,
            enhancedArtist: song.hasEnhancedData ? song.enhancedArtist : nil,
            enhancedAlbum: song.hasEnhancedData ? song.enhancedAlbum : nil,
            enhancedReleaseDate: song.hasEnhancedData ? song.enhancedReleaseDate : nil,
            enhancedComposer: song.hasEnhancedData ? song.enhancedComposer : nil,
            enhancedTrackNumber: song.hasEnhancedData ? song.musicKitSong?.trackNumber : nil,
            enhancedDiscNumber: song.hasEnhancedData ? song.mediaItem.value(forProperty: MPMediaItemPropertyDiscNumber) as? Int : nil,
            isExplicit: song.isExplicit,
            hasEnhancedData: song.hasEnhancedData,
            artworkURL: song.enhancedArtwork?.url(width: 300, height: 300)?.absoluteString
        )
        
        do {
            let data = try JSONEncoder().encode(cachedData)
            let key = UserDefaultsKeys.enhancedSongKey(for: song.id)
            userDefaults.set(data, forKey: key)
            
            // Update metadata
            updateEnhancedSongMetadata(songId: song.id, hasEnhancedData: song.hasEnhancedData)
            
            logger.log("Cached enhanced song data for '\(song.title)'", level: .debug)
        } catch {
            logger.log("Failed to cache enhanced song '\(song.title)': \(error.localizedDescription)", level: .error)
        }
    }
    
    func getCachedEnhancedSong(for songId: String) -> Song? {
        let key = UserDefaultsKeys.enhancedSongKey(for: songId)
        
        guard let data = userDefaults.data(forKey: key),
              let cachedData = try? JSONDecoder().decode(CachedSongData.self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid
        if !isCacheValid(for: songId) {
            // Remove expired cache
            userDefaults.removeObject(forKey: key)
            removeFromMetadata(songId: songId)
            return nil
        }
        
        // We can't fully reconstruct a Song object without the MPMediaItem
        // This is a limitation of caching to UserDefaults
        // The calling code should handle merging cached data with current MediaPlayer data
        logger.log("Retrieved cached enhanced song data for ID: \(songId)", level: .debug)
        return nil // We'll need to modify the approach - see next iteration
    }
    
    func isSongEnhanced(_ songId: String) -> Bool {
        let metadata = getEnhancedSongMetadata()
        return metadata.contains { $0.songId == songId && $0.hasEnhancedData }
    }
    
    func clearEnhancedSongCache() {
        let metadata = getEnhancedSongMetadata()
        
        for item in metadata {
            let key = UserDefaultsKeys.enhancedSongKey(for: item.songId)
            userDefaults.removeObject(forKey: key)
        }
        
        userDefaults.removeObject(forKey: UserDefaultsKeys.enhancedSongMetadata)
        
        logger.log("Cleared enhanced song cache: \(metadata.count) entries removed", level: .info)
    }
    
    func cleanupOldEnhancedSongs() {
        var metadata = getEnhancedSongMetadata()
        let oldEntries = metadata.filter { Date().timeIntervalSince($0.timestamp) > maxCacheAge }
        
        for entry in oldEntries {
            let key = UserDefaultsKeys.enhancedSongKey(for: entry.songId)
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove old entries from metadata
        metadata.removeAll { oldEntries.contains($0) }
        
        // If we have too many entries, remove oldest ones
        if metadata.count > maxCachedSongs {
            let sortedMetadata = metadata.sorted { $0.timestamp < $1.timestamp }
            let toRemove = sortedMetadata.prefix(metadata.count - maxCachedSongs)
            
            for entry in toRemove {
                let key = UserDefaultsKeys.enhancedSongKey(for: entry.songId)
                userDefaults.removeObject(forKey: key)
            }
            
            metadata = Array(sortedMetadata.suffix(maxCachedSongs))
        }
        
        // Save updated metadata
        saveEnhancedSongMetadata(metadata)
        
        if !oldEntries.isEmpty {
            logger.log("Cleaned up \(oldEntries.count) old enhanced song cache entries", level: .debug)
        }
    }
    
    func getEnhancedSongCacheSize() -> String {
        let metadata = getEnhancedSongMetadata()
        
        var totalSize = 0
        for item in metadata {
            let key = UserDefaultsKeys.enhancedSongKey(for: item.songId)
            if let data = userDefaults.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    // MARK: - Private Methods
    
    private func updateEnhancedSongMetadata(songId: String, hasEnhancedData: Bool) {
        var metadata = getEnhancedSongMetadata()
        
        // Remove existing entry if present
        metadata.removeAll { $0.songId == songId }
        
        // Add new entry
        metadata.append(EnhancedSongMetadata(
            songId: songId,
            timestamp: Date(),
            hasEnhancedData: hasEnhancedData
        ))
        
        saveEnhancedSongMetadata(metadata)
    }
    
    private func removeFromMetadata(songId: String) {
        var metadata = getEnhancedSongMetadata()
        metadata.removeAll { $0.songId == songId }
        saveEnhancedSongMetadata(metadata)
    }
    
    private func getEnhancedSongMetadata() -> [EnhancedSongMetadata] {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.enhancedSongMetadata),
              let metadata = try? JSONDecoder().decode([EnhancedSongMetadata].self, from: data) else {
            return []
        }
        return metadata
    }
    
    private func saveEnhancedSongMetadata(_ metadata: [EnhancedSongMetadata]) {
        do {
            let data = try JSONEncoder().encode(metadata)
            userDefaults.set(data, forKey: UserDefaultsKeys.enhancedSongMetadata)
        } catch {
            logger.log("Failed to save enhanced song metadata: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func isCacheValid(for songId: String) -> Bool {
        let metadata = getEnhancedSongMetadata()
        guard let entry = metadata.first(where: { $0.songId == songId }) else {
            return false
        }
        
        return Date().timeIntervalSince(entry.timestamp) <= maxCacheAge
    }
}

// MARK: - Comparable conformance for metadata sorting

extension EnhancedSongMetadata: Comparable {
    static func < (lhs: EnhancedSongMetadata, rhs: EnhancedSongMetadata) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
    
    static func == (lhs: EnhancedSongMetadata, rhs: EnhancedSongMetadata) -> Bool {
        lhs.songId == rhs.songId
    }
}
