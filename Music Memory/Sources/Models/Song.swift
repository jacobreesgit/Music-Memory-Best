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
    
    // MARK: - MusicKit Enhancement Properties (Ready for Future Implementation)
    let musicKitTrack: MusicKit.Song?
    let enhancedArtwork: Artwork?
    
    // MARK: - Local Play Count Support
    
    /// Computed property that combines system play count with local tracking
    var displayedPlayCount: Int {
        return playCount + localPlayCount
    }
    
    /// Local play count stored in UserDefaults
    var localPlayCount: Int {
        UserDefaults.standard.integer(forKey: "localPlayCount_\(id)")
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
        
        // MusicKit enhancements (for future implementation)
        self.musicKitTrack = musicKitTrack
        self.enhancedArtwork = musicKitTrack?.artwork
    }
    
    // MARK: - Enhanced Data Access
    
    /// Get the best available artwork, preferring MusicKit if available
    var bestArtwork: Artwork? {
        return enhancedArtwork // Will be nil for now, enhanced in future
    }
    
    /// Check if enhanced MusicKit data is available
    var hasEnhancedData: Bool {
        return musicKitTrack != nil // Will be false for now, ready for future enhancement
    }
    
    // MARK: - Local Play Count Methods (UNCHANGED - Critical to Preserve)
    
    /// Increment the local play count for this song
    func incrementLocalPlayCount() {
        let currentLocal = localPlayCount
        UserDefaults.standard.set(currentLocal + 1, forKey: "localPlayCount_\(id)")
    }
    
    /// Get the baseline system play count
    var baselinePlayCount: Int {
        UserDefaults.standard.integer(forKey: "baselinePlayCount_\(id)")
    }
    
    /// Update the baseline play count
    func updateBaselinePlayCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "baselinePlayCount_\(id)")
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
            
            UserDefaults.standard.set(newLocal, forKey: "localPlayCount_\(id)")
            
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
