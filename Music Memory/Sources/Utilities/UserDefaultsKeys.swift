import Foundation

/// Centralized UserDefaults keys for the Music Memory app
enum UserDefaultsKeys {
    // MARK: - Local Play Count Tracking
    static func localPlayCountKey(for songId: String) -> String {
        "localPlayCount_\(songId)"
    }
    
    static func baselinePlayCountKey(for songId: String) -> String {
        "baselinePlayCount_\(songId)"
    }
    
    // MARK: - Rank History
    static func rankSnapshotsKey(for sortDescriptor: SortDescriptor) -> String {
        "rankSnapshots_\(sortDescriptor.key)"
    }
    
    // MARK: - Enhanced Song Cache
    static func enhancedSongKey(for songId: String) -> String {
        "enhancedSong_\(songId)"
    }
    
    static let enhancedSongMetadata = "enhancedSongMetadata"
    
    // MARK: - MusicKit Search Cache
    static func musicKitSearchKey(for searchTerm: String) -> String {
        "musicKitSearch_\(searchTerm.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    
    static let musicKitSearchMetadata = "musicKitSearchMetadata"
    
    // MARK: - Artwork Cache
    static func artworkKey(for songId: String) -> String {
        "artwork_\(songId)"
    }
    
    static let artworkMetadata = "artworkMetadata"
    static let savedArtworkSongId = "savedArtworkSongId"
    static let savedArtworkTimestamp = "savedArtworkTimestamp"
    
    // MARK: - Cache Management
    static let cacheLastCleanupDate = "cacheLastCleanupDate"
    
    /// Get all prefixes used by the app for comprehensive cleanup
    static let allKeyPrefixes: [String] = [
        "localPlayCount_",
        "baselinePlayCount_",
        "rankSnapshots_",
        "enhancedSong_",
        "musicKitSearch_",
        "artwork_",
        enhancedSongMetadata,
        musicKitSearchMetadata,
        artworkMetadata,
        savedArtworkSongId,
        savedArtworkTimestamp,
        cacheLastCleanupDate
    ]
}
