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
    }
    
    // MARK: - Enhanced Data Access
    
    /// Check if enhanced MusicKit data is available
    var hasEnhancedData: Bool {
        return musicKitSong != nil
    }
    
    /// Get enhanced genre information from MusicKit or fallback to MediaPlayer
    var enhancedGenre: String {
        // Try MusicKit first for richer genre data
        if let musicKitGenres = musicKitSong?.genreNames, !musicKitGenres.isEmpty {
            return musicKitGenres.joined(separator: ", ")
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyGenre) as? String ?? "Unknown"
    }
    
    /// Get enhanced duration from MusicKit or fallback to MediaPlayer
    var enhancedDuration: TimeInterval {
        // MusicKit duration is more accurate
        if let musicKitDuration = musicKitSong?.duration {
            return musicKitDuration
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyPlaybackDuration) as? TimeInterval ?? 0
    }
    
    /// Get enhanced artist name from MusicKit or fallback to MediaPlayer
    var enhancedArtist: String {
        // MusicKit might have more accurate artist information
        if let musicKitArtist = musicKitSong?.artistName {
            return musicKitArtist
        }
        
        return artist
    }
    
    /// Get enhanced album name from MusicKit or fallback to MediaPlayer
    var enhancedAlbum: String {
        // MusicKit might have more accurate album information
        if let musicKitAlbum = musicKitSong?.albumTitle {
            return musicKitAlbum
        }
        
        return album
    }
    
    /// Get release date from MusicKit or MediaPlayer
    var enhancedReleaseDate: Date? {
        // Try MusicKit first
        if let musicKitReleaseDate = musicKitSong?.releaseDate {
            return musicKitReleaseDate
        }
        
        // Fallback to MediaPlayer
        return mediaItem.value(forProperty: MPMediaItemPropertyReleaseDate) as? Date
    }
    
    /// Get composer information with MusicKit enhancement
    var enhancedComposer: String {
        // Try MusicKit composer information first
        if let musicKitComposer = musicKitSong?.composerName {
            return musicKitComposer
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
            
            // Add total tracks if available
            if let _ = musicKitSong?.albumTitle {
                // MusicKit doesn't directly provide total tracks, so use MediaPlayer fallback
                if let mpTrackCount = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackCount) as? Int {
                    trackNumber = "\(musicKitTrackNumber) of \(mpTrackCount)"
                }
            }
        } else if let mpTrackNumber = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackNumber) as? Int {
            let totalTracks = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackCount) as? Int
            if let total = totalTracks {
                trackNumber = "\(mpTrackNumber) of \(total)"
            } else {
                trackNumber = "\(mpTrackNumber)"
            }
        }
        
        // Disc number handling
        if let mpDiscNumber = mediaItem.value(forProperty: MPMediaItemPropertyDiscNumber) as? Int {
            let totalDiscs = mediaItem.value(forProperty: MPMediaItemPropertyDiscCount) as? Int
            if let total = totalDiscs {
                discNumber = "\(mpDiscNumber) of \(total)"
            } else {
                discNumber = "\(mpDiscNumber)"
            }
        }
        
        return (trackNumber: trackNumber, discNumber: discNumber)
    }
    
    /// Check if song has explicit content (from MusicKit)
    var isExplicit: Bool {
        return musicKitSong?.contentRating == .explicit
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
        let key = UserDefaultsKeys.enhancedSongKey(for: id)
        return UserDefaults.standard.data(forKey: key) != nil
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
