import Foundation
import MediaPlayer
import MusicKit

struct Song: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let playCount: Int
    let artwork: MPMediaItemArtwork?
    let mediaItem: MPMediaItem
    
    // MARK: - MusicKit Enhancement Properties
    let musicKitSong: MusicKit.Song?
    let enhancedArtwork: Artwork?
    
    // MARK: - Cached Enhancement Data (CRITICAL FIX)
    private let cachedEnhancement: CachedSongEnhancement?
    
    // MARK: - Local Play Count Support (UNCHANGED - Critical to Preserve)
    
    /// Computed property that combines system play count with local tracking
    var displayedPlayCount: Int {
        return playCount + localPlayCount
    }
    
    /// Local play count stored in UserDefaults using centralized key management
    var localPlayCount: Int {
        let key = UserDefaultsKeys.localPlayCountKey(for: id)
        return UserDefaults.standard.integer(forKey: key)
    }
    
    init(from mediaItem: MPMediaItem, musicKitTrack: MusicKit.Song? = nil) {
        self.id = mediaItem.persistentID.stringValue
        self.title = mediaItem.title ?? "Unknown Title"
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.album = mediaItem.albumTitle ?? "Unknown Album"
        // Force fresh read of play count
        self.playCount = mediaItem.value(forProperty: MPMediaItemPropertyPlayCount) as? Int ?? 0
        self.artwork = mediaItem.artwork
        self.mediaItem = mediaItem
        
        // MusicKit enhancements
        self.musicKitSong = musicKitTrack
        self.enhancedArtwork = musicKitTrack?.artwork
        
        // CRITICAL FIX: Load cached enhancement data
        self.cachedEnhancement = Self.loadCachedEnhancement(for: self.id)
    }
    
    // CRITICAL FIX: Method to load cached enhancement data
    private static func loadCachedEnhancement(for songId: String) -> CachedSongEnhancement? {
        let key = UserDefaultsKeys.enhancedSongKey(for: songId)
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let cachedEnhancement = try? JSONDecoder().decode(CachedSongEnhancement.self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid
        let maxAge: TimeInterval = 14 * 24 * 60 * 60 // 14 days
        if Date().timeIntervalSince(cachedEnhancement.timestamp) > maxAge {
            return nil
        }
        
        if cachedEnhancement.version != CachedSongEnhancement.currentVersion {
            return nil
        }
        
        return cachedEnhancement
    }
    
    // MARK: - Enhanced Data Access (CRITICAL FIX: Use cached data when available)
    
    /// Check if enhanced MusicKit data is available (either live or cached)
    var hasEnhancedData: Bool {
        return musicKitSong != nil || cachedEnhancement != nil
    }
    
    /// Get enhanced genre information from MusicKit, cache, or fallback to MediaPlayer
    var enhancedGenre: String {
        // Try MusicKit first for richer genre data
        if let musicKitGenres = musicKitSong?.genreNames, !musicKitGenres.isEmpty {
            return musicKitGenres.joined(separator: ", ")
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedGenre = cachedEnhancement?.enhancedGenre {
            return cachedGenre
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyGenre) as? String ?? "Unknown"
    }
    
    /// Get enhanced duration from MusicKit, cache, or fallback to MediaPlayer
    var enhancedDuration: TimeInterval {
        // MusicKit duration is more accurate
        if let musicKitDuration = musicKitSong?.duration {
            return musicKitDuration
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedDuration = cachedEnhancement?.enhancedDuration {
            return cachedDuration
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyPlaybackDuration) as? TimeInterval ?? 0
    }
    
    /// Get enhanced artist name from MusicKit, cache, or fallback to MediaPlayer
    var enhancedArtist: String {
        // MusicKit might have more accurate artist information
        if let musicKitArtist = musicKitSong?.artistName {
            return musicKitArtist
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedArtist = cachedEnhancement?.enhancedArtist {
            return cachedArtist
        }
        
        return artist
    }
    
    /// Get enhanced album name from MusicKit, cache, or fallback to MediaPlayer
    var enhancedAlbum: String {
        // MusicKit might have more accurate album information
        if let musicKitAlbum = musicKitSong?.albumTitle {
            return musicKitAlbum
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedAlbum = cachedEnhancement?.enhancedAlbum {
            return cachedAlbum
        }
        
        return album
    }
    
    /// Get release date from MusicKit, cache, or MediaPlayer
    var enhancedReleaseDate: Date? {
        // Try MusicKit first
        if let musicKitReleaseDate = musicKitSong?.releaseDate {
            return musicKitReleaseDate
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedReleaseDate = cachedEnhancement?.enhancedReleaseDate {
            return cachedReleaseDate
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyReleaseDate) as? Date
    }
    
    /// Get composer information with MusicKit, cache, or MediaPlayer enhancement
    var enhancedComposer: String {
        // Try MusicKit composer information first
        if let musicKitComposer = musicKitSong?.composerName {
            return musicKitComposer
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedComposer = cachedEnhancement?.enhancedComposer {
            return cachedComposer
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyComposer) as? String ?? "Unknown"
    }
    
    /// Get track and disc numbers with enhanced formatting
    var enhancedTrackInfo: (trackNumber: String, discNumber: String) {
        var trackNumber = "Unknown"
        var discNumber = "Unknown"
        
        // Try MusicKit first for track information
        if let musicKitTrackNumber = musicKitSong?.trackNumber {
            trackNumber = "\(musicKitTrackNumber)"
            
            // Add total tracks if available from MediaPlayer
            if let mpTrackCount = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackCount) as? Int {
                trackNumber = "\(musicKitTrackNumber) of \(mpTrackCount)"
            }
        }
        // CRITICAL FIX: Try cached data
        else if let cachedTrackNumber = cachedEnhancement?.enhancedTrackNumber {
            trackNumber = "\(cachedTrackNumber)"
            
            // Add total tracks if available from MediaPlayer
            if let mpTrackCount = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackCount) as? Int {
                trackNumber = "\(cachedTrackNumber) of \(mpTrackCount)"
            }
        }
        // Fallback to MediaPlayer
        else if let mpTrackNumber = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackNumber) as? Int {
            let totalTracks = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackCount) as? Int
            if let total = totalTracks {
                trackNumber = "\(mpTrackNumber) of \(total)"
            } else {
                trackNumber = "\(mpTrackNumber)"
            }
        }
        
        // Disc number handling (try cached data first)
        if let cachedDiscNumber = cachedEnhancement?.enhancedDiscNumber {
            let totalDiscs = mediaItem.value(forProperty: MPMediaItemPropertyDiscCount) as? Int
            if let total = totalDiscs {
                discNumber = "\(cachedDiscNumber) of \(total)"
            } else {
                discNumber = "\(cachedDiscNumber)"
            }
        } else if let mpDiscNumber = mediaItem.value(forProperty: MPMediaItemPropertyDiscNumber) as? Int {
            let totalDiscs = mediaItem.value(forProperty: MPMediaItemPropertyDiscCount) as? Int
            if let total = totalDiscs {
                discNumber = "\(mpDiscNumber) of \(total)"
            } else {
                discNumber = "\(mpDiscNumber)"
            }
        }
        
        return (trackNumber: trackNumber, discNumber: discNumber)
    }
    
    /// Check if song has explicit content (from MusicKit or cache)
    var isExplicit: Bool {
        if let explicit = musicKitSong?.contentRating {
            return explicit == .explicit
        }
        
        // CRITICAL FIX: Try cached data
        if let cachedExplicit = cachedEnhancement?.isExplicit {
            return cachedExplicit
        }
        
        return false
    }
    
    /// CRITICAL FIX: Enhanced artwork with cache support
    var enhancedArtworkURL: URL? {
        // Try MusicKit first
        if let artwork = enhancedArtwork {
            return artwork.url(width: 300, height: 300)
        }
        
        // Try cached artwork URL
        if let cachedArtworkURLString = cachedEnhancement?.artworkURL,
           let cachedArtworkURL = URL(string: cachedArtworkURLString) {
            return cachedArtworkURL
        }
        
        return nil
    }
    
    // MARK: - Local Play Count Methods (Updated to use centralized UserDefaults keys)
    
    /// Increment the local play count for this song
    func incrementLocalPlayCount() {
        let currentLocal = localPlayCount
        let key = UserDefaultsKeys.localPlayCountKey(for: id)
        UserDefaults.standard.set(currentLocal + 1, forKey: key)
    }
    
    /// Get the baseline system play count using centralized key management
    var baselinePlayCount: Int {
        let key = UserDefaultsKeys.baselinePlayCountKey(for: id)
        return UserDefaults.standard.integer(forKey: key)
    }
    
    /// Update the baseline play count using centralized key management
    func updateBaselinePlayCount(_ count: Int) {
        let key = UserDefaultsKeys.baselinePlayCountKey(for: id)
        UserDefaults.standard.set(count, forKey: key)
    }
    
    /// Sync local count with system count (called on app launch)
    func syncPlayCounts(logger: LoggerProtocol) {
        let currentSystemCount = playCount
        let storedBaseline = baselinePlayCount
        let currentLocal = localPlayCount
        let systemIncrease = currentSystemCount - storedBaseline
        
        logger.log("Play count sync for '\(title)': System=\(currentSystemCount), Baseline=\(storedBaseline), Local=\(currentLocal), Increase=\(systemIncrease)", level: .info)
        
        if systemIncrease > 0 {
            // System caught up, reduce local count
            let newLocal = max(0, currentLocal - systemIncrease)
            
            logger.log("System play count increased by \(systemIncrease) for '\(title)'. Reducing local count from \(currentLocal) to \(newLocal)", level: .info)
            
            let localKey = UserDefaultsKeys.localPlayCountKey(for: id)
            UserDefaults.standard.set(newLocal, forKey: localKey)
            
            // Update baseline
            updateBaselinePlayCount(currentSystemCount)
            
            logger.log("Updated baseline play count to \(currentSystemCount) for '\(title)'", level: .info)
        } else if systemIncrease < 0 {
            // Edge case: system count decreased (shouldn't happen normally)
            logger.log("WARNING: System play count decreased by \(abs(systemIncrease)) for '\(title)'. This is unexpected.", level: .warning)
            // Update baseline to current system count to prevent issues
            updateBaselinePlayCount(currentSystemCount)
        } else {
            // No change in system count
            logger.log("No system play count change for '\(title)'", level: .debug)
        }
    }
    
    // MARK: - Cache Management Helpers
    
    /// Check if this song has cached enhanced data
    func hasCachedEnhancedData() -> Bool {
        return cachedEnhancement != nil
    }
    
    /// Check if this song has cached artwork
    func hasCachedArtwork() -> Bool {
        let key = UserDefaultsKeys.artworkKey(for: id)
        return UserDefaults.standard.data(forKey: key) != nil
    }
    
    /// Get all UserDefaults keys associated with this song for debugging
    func getAllAssociatedUserDefaultsKeys() -> [String] {
        return [
            UserDefaultsKeys.localPlayCountKey(for: id),
            UserDefaultsKeys.baselinePlayCountKey(for: id),
            UserDefaultsKeys.enhancedSongKey(for: id),
            UserDefaultsKeys.artworkKey(for: id)
        ]
    }
    
    /// Clear all cached data for this song (useful for testing)
    func clearAllCachedData() {
        let keys = getAllAssociatedUserDefaultsKeys()
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    /// CRITICAL FIX: Get cache status for debugging
    func getCacheStatus() -> (hasEnhanced: Bool, hasArtwork: Bool, cacheAge: TimeInterval?) {
        let hasEnhanced = hasCachedEnhancedData()
        let hasArtwork = hasCachedArtwork()
        let cacheAge = cachedEnhancement?.timestamp.timeIntervalSinceNow.magnitude
        
        return (hasEnhanced: hasEnhanced, hasArtwork: hasArtwork, cacheAge: cacheAge)
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        // Only compare by ID for equality
        lhs.id == rhs.id
    }
    
    // Add hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension MPMediaEntityPersistentID {
    var stringValue: String {
        String(format: "%llx", self)
    }
}

// MARK: - Cached Song Enhancement Model (moved here for Song access)

/// Lightweight cached song enhancement data
struct CachedSongEnhancement: Codable {
    let songId: String
    let timestamp: Date
    let version: Int // For cache versioning
    
    // MusicKit data that we can cache
    let musicKitSongId: String?
    let enhancedGenre: String?
    let enhancedDuration: TimeInterval?
    let enhancedArtist: String?
    let enhancedAlbum: String?
    let enhancedReleaseDate: Date?
    let enhancedComposer: String?
    let enhancedTrackNumber: Int?
    let enhancedDiscNumber: Int?
    let isExplicit: Bool
    let artworkURL: String? // Cache the URL for artwork
    
    // Validation
    let originalTitle: String // To validate we're getting the right song
    let originalArtist: String
    
    static let currentVersion = 1
}
