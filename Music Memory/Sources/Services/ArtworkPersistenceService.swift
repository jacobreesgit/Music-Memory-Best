import Foundation
import UIKit
import MediaPlayer

protocol ArtworkPersistenceServiceProtocol {
    func saveCurrentArtwork(songId: String, artwork: UIImage?)
    func loadSavedArtwork(for songId: String) -> UIImage?
    func clearSavedArtwork()
    func cleanupOldArtwork()
    func getArtworkCacheSize() -> String
    func cacheArtworkForSong(_ songId: String, artwork: UIImage?)
    func getCachedArtwork(for songId: String) -> UIImage?
    func getArtworkCacheValidationInfo() -> (valid: Int, stale: Int, corrupted: Int)
}

/// Metadata for tracking artwork cache with validation
struct ArtworkMetadata: Codable {
    let songId: String
    let timestamp: Date
    let dataSize: Int
    let isCurrentlyPlaying: Bool
    let version: Int
    
    static let currentVersion = 1
}

class ArtworkPersistenceService: ArtworkPersistenceServiceProtocol {
    private let logger: LoggerProtocol
    private let userDefaults = UserDefaults.standard
    private let artworkMaxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days (longer for better UX)
    private let currentPlayingMaxAge: TimeInterval = 24 * 60 * 60 // 24 hours for currently playing
    private let maxArtworkCacheSize: Int = 100 * 1024 * 1024 // 100MB limit for artwork cache
    private let artworkCompressionQuality: CGFloat = 0.7 // Better quality for better UX
    private let maxCachedArtworks = 200 // Higher limit for better UX
    private let queue = DispatchQueue(label: "artwork-persistence", qos: .utility)
    
    init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    // MARK: - Currently Playing Artwork (Legacy API)
    
    func saveCurrentArtwork(songId: String, artwork: UIImage?) {
        queue.async { [weak self] in
            self?._saveCurrentArtwork(songId: songId, artwork: artwork)
        }
    }
    
    private func _saveCurrentArtwork(songId: String, artwork: UIImage?) {
        guard let artwork = artwork else {
            logger.log("No artwork to save for currently playing song ID: \(songId)", level: .debug)
            return
        }
        
        logger.log("Saving currently playing artwork for song ID: \(songId)", level: .info)
        
        // Use the general caching method but mark as currently playing
        _cacheArtworkForSong(songId, artwork: artwork, isCurrentlyPlaying: true)
        
        // Save currently playing artwork info
        userDefaults.set(songId, forKey: UserDefaultsKeys.savedArtworkSongId)
        userDefaults.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.savedArtworkTimestamp)
        
        logger.log("Successfully saved currently playing artwork for song ID: \(songId)", level: .info)
    }
    
    func loadSavedArtwork(for songId: String) -> UIImage? {
        return queue.sync { [weak self] in
            return self?._loadSavedArtwork(for: songId)
        }
    }
    
    private func _loadSavedArtwork(for songId: String) -> UIImage? {
        // Check if we have saved artwork for this song
        guard let savedSongId = userDefaults.string(forKey: UserDefaultsKeys.savedArtworkSongId),
              savedSongId == songId else {
            logger.log("No saved currently playing artwork found for song ID: \(songId)", level: .debug)
            return nil
        }
        
        // Check if the saved artwork is not too old
        let savedTimestamp = userDefaults.double(forKey: UserDefaultsKeys.savedArtworkTimestamp)
        let age = Date().timeIntervalSince1970 - savedTimestamp
        
        if age > currentPlayingMaxAge {
            logger.log("Saved currently playing artwork is too old (\(Int(age / 3600)) hours), clearing it", level: .info)
            clearSavedArtwork()
            return nil
        }
        
        // Use the general cache loading method
        return _getCachedArtwork(for: songId)
    }
    
    func clearSavedArtwork() {
        queue.async { [weak self] in
            self?._clearSavedArtwork()
        }
    }
    
    private func _clearSavedArtwork() {
        // Clear the currently playing artwork metadata
        userDefaults.removeObject(forKey: UserDefaultsKeys.savedArtworkSongId)
        userDefaults.removeObject(forKey: UserDefaultsKeys.savedArtworkTimestamp)
        
        logger.log("Cleared currently playing artwork metadata", level: .debug)
    }
    
    // MARK: - General Artwork Caching (CRITICAL FIX)
    
    func cacheArtworkForSong(_ songId: String, artwork: UIImage?) {
        queue.async { [weak self] in
            self?._cacheArtworkForSong(songId, artwork: artwork, isCurrentlyPlaying: false)
        }
    }
    
    private func _cacheArtworkForSong(_ songId: String, artwork: UIImage?, isCurrentlyPlaying: Bool) {
        guard let artwork = artwork else {
            logger.log("No artwork to cache for song ID: \(songId)", level: .debug)
            return
        }
        
        logger.log("Caching artwork for song ID: \(songId) (currently playing: \(isCurrentlyPlaying))", level: .debug)
        
        // Resize artwork to reasonable size before compression
        let targetSize = isCurrentlyPlaying ? CGSize(width: 600, height: 600) : CGSize(width: 300, height: 300)
        let resizedArtwork = resizeImage(artwork, targetSize: targetSize)
        
        // Convert image to data with compression
        guard let imageData = resizedArtwork.jpegData(compressionQuality: artworkCompressionQuality) else {
            logger.log("Failed to convert artwork to data for song ID: \(songId)", level: .error)
            return
        }
        
        // Check if adding this artwork would exceed cache size limits
        if !isCurrentlyPlaying && shouldSkipCaching(newDataSize: imageData.count) {
            logger.log("Skipping artwork cache for song ID: \(songId) - cache size limit reached", level: .warning)
            return
        }
        
        let key = UserDefaultsKeys.artworkKey(for: songId)
        userDefaults.set(imageData, forKey: key)
        
        // Update metadata for cache management
        updateArtworkMetadata(songId: songId, dataSize: imageData.count, isCurrentlyPlaying: isCurrentlyPlaying)
        
        logger.log("Successfully cached artwork for song ID: \(songId) (\(imageData.count) bytes)", level: .debug)
    }
    
    func getCachedArtwork(for songId: String) -> UIImage? {
        return queue.sync { [weak self] in
            return self?._getCachedArtwork(for: songId)
        }
    }
    
    private func _getCachedArtwork(for songId: String) -> UIImage? {
        let key = UserDefaultsKeys.artworkKey(for: songId)
        
        guard let imageData = userDefaults.data(forKey: key),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        // Check if cache is still valid
        if !isCacheValid(for: songId) {
            // Remove expired cache
            userDefaults.removeObject(forKey: key)
            removeFromArtworkMetadata(songId: songId)
            logger.log("Removed expired artwork cache for song ID: \(songId)", level: .debug)
            return nil
        }
        
        logger.log("Retrieved cached artwork for song ID: \(songId)", level: .debug)
        return image
    }
    
    func cleanupOldArtwork() {
        queue.async { [weak self] in
            self?._cleanupOldArtwork()
        }
    }
    
    private func _cleanupOldArtwork() {
        var metadata = getArtworkMetadata()
        let oldEntries = metadata.filter {
            let maxAge = $0.isCurrentlyPlaying ? currentPlayingMaxAge : artworkMaxAge
            return Date().timeIntervalSince($0.timestamp) > maxAge
        }
        
        // Remove old artwork entries
        for entry in oldEntries {
            let key = UserDefaultsKeys.artworkKey(for: entry.songId)
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove old entries from metadata
        metadata.removeAll { oldEntries.contains($0) }
        
        // Validate remaining cache entries
        let (validMetadata, corruptedEntries) = validateArtworkCacheEntries(metadata)
        
        // Remove corrupted entries
        for entry in corruptedEntries {
            let key = UserDefaultsKeys.artworkKey(for: entry.songId)
            userDefaults.removeObject(forKey: key)
        }
        
        metadata = validMetadata
        
        // If we have too many artworks, remove oldest ones (keep currently playing)
        if metadata.count > maxCachedArtworks {
            let currentlyPlayingEntries = metadata.filter { $0.isCurrentlyPlaying }
            let regularEntries = metadata.filter { !$0.isCurrentlyPlaying }
            
            // Sort regular entries by timestamp and keep only the newest ones
            let sortedRegularEntries = regularEntries.sorted { $0.timestamp > $1.timestamp }
            let keepCount = maxCachedArtworks - currentlyPlayingEntries.count
            let toRemove = sortedRegularEntries.dropFirst(max(0, keepCount))
            
            for entry in toRemove {
                let key = UserDefaultsKeys.artworkKey(for: entry.songId)
                userDefaults.removeObject(forKey: key)
            }
            
            metadata = currentlyPlayingEntries + Array(sortedRegularEntries.prefix(keepCount))
        }
        
        // Check total cache size and remove entries if needed
        metadata = enforceArtworkCacheSizeLimit(metadata: metadata)
        
        // Save updated metadata
        saveArtworkMetadata(metadata)
        
        let totalRemoved = oldEntries.count + corruptedEntries.count
        if totalRemoved > 0 {
            logger.log("Cleaned up \(totalRemoved) artwork cache entries (\(oldEntries.count) old, \(corruptedEntries.count) corrupted)", level: .debug)
        }
    }
    
    func getArtworkCacheSize() -> String {
        return queue.sync { [weak self] in
            guard let self = self else { return "0 KB" }
            
            let metadata = getArtworkMetadata()
            let totalSize = metadata.reduce(0) { $0 + $1.dataSize }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(totalSize))
        }
    }
    
    func getArtworkCacheValidationInfo() -> (valid: Int, stale: Int, corrupted: Int) {
        return queue.sync { [weak self] in
            guard let self = self else { return (0, 0, 0) }
            
            let metadata = getArtworkMetadata()
            var valid = 0
            var stale = 0
            var corrupted = 0
            
            for entry in metadata {
                let key = UserDefaultsKeys.artworkKey(for: entry.songId)
                
                guard let data = userDefaults.data(forKey: key),
                      !data.isEmpty,
                      UIImage(data: data) != nil else {
                    corrupted += 1
                    continue
                }
                
                if !isCacheValid(for: entry.songId) {
                    stale += 1
                } else {
                    valid += 1
                }
            }
            
            return (valid: valid, stale: stale, corrupted: corrupted)
        }
    }
    
    // MARK: - Private Methods
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        // Only resize if the image is actually larger than target
        let imageSize = image.size
        if imageSize.width <= targetSize.width && imageSize.height <= targetSize.height {
            return image
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func shouldSkipCaching(newDataSize: Int) -> Bool {
        let metadata = getArtworkMetadata()
        let currentCacheSize = metadata.reduce(0) { $0 + $1.dataSize }
        
        return (currentCacheSize + newDataSize) > maxArtworkCacheSize
    }
    
    private func isCacheValid(for songId: String) -> Bool {
        let metadata = getArtworkMetadata()
        guard let entry = metadata.first(where: { $0.songId == songId }) else {
            return false
        }
        
        // Check version
        if entry.version != ArtworkMetadata.currentVersion {
            return false
        }
        
        // Check age based on type
        let maxAge = entry.isCurrentlyPlaying ? currentPlayingMaxAge : artworkMaxAge
        return Date().timeIntervalSince(entry.timestamp) <= maxAge
    }
    
    private func validateArtworkCacheEntries(_ metadata: [ArtworkMetadata]) -> (valid: [ArtworkMetadata], corrupted: [ArtworkMetadata]) {
        var valid: [ArtworkMetadata] = []
        var corrupted: [ArtworkMetadata] = []
        
        for entry in metadata {
            let key = UserDefaultsKeys.artworkKey(for: entry.songId)
            
            guard let data = userDefaults.data(forKey: key),
                  !data.isEmpty,
                  UIImage(data: data) != nil else {
                corrupted.append(entry)
                continue
            }
            
            // Check if entry is still valid
            if isCacheValid(for: entry.songId) {
                valid.append(entry)
            } else {
                corrupted.append(entry)
            }
        }
        
        return (valid: valid, corrupted: corrupted)
    }
    
    private func enforceArtworkCacheSizeLimit(metadata: [ArtworkMetadata]) -> [ArtworkMetadata] {
        let targetSize = Int(Double(maxArtworkCacheSize) * 0.8) // Keep cache at 80% of limit
        
        // Separate currently playing from regular entries
        let currentlyPlayingEntries = metadata.filter { $0.isCurrentlyPlaying }
        var regularEntries = metadata.filter { !$0.isCurrentlyPlaying }
        
        // Sort regular entries by timestamp (newest first)
        regularEntries.sort { $0.timestamp > $1.timestamp }
        
        var currentSize = currentlyPlayingEntries.reduce(0) { $0 + $1.dataSize }
        var validMetadata = currentlyPlayingEntries
        
        // Add regular entries until we hit the size limit
        for entry in regularEntries {
            if currentSize + entry.dataSize <= targetSize {
                validMetadata.append(entry)
                currentSize += entry.dataSize
            } else {
                // Remove this entry as it would exceed our target
                let key = UserDefaultsKeys.artworkKey(for: entry.songId)
                userDefaults.removeObject(forKey: key)
            }
        }
        
        let removedCount = metadata.count - validMetadata.count
        if removedCount > 0 {
            logger.log("Removed \(removedCount) artwork entries to enforce cache size limit", level: .debug)
        }
        
        return validMetadata
    }
    
    private func updateArtworkMetadata(songId: String, dataSize: Int, isCurrentlyPlaying: Bool) {
        var metadata = getArtworkMetadata()
        
        // Remove existing entry if present
        metadata.removeAll { $0.songId == songId }
        
        // Add new entry
        metadata.append(ArtworkMetadata(
            songId: songId,
            timestamp: Date(),
            dataSize: dataSize,
            isCurrentlyPlaying: isCurrentlyPlaying,
            version: ArtworkMetadata.currentVersion
        ))
        
        saveArtworkMetadata(metadata)
    }
    
    private func removeFromArtworkMetadata(songId: String) {
        var metadata = getArtworkMetadata()
        metadata.removeAll { $0.songId == songId }
        saveArtworkMetadata(metadata)
    }
    
    private func getArtworkMetadata() -> [ArtworkMetadata] {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.artworkMetadata),
              let metadata = try? JSONDecoder().decode([ArtworkMetadata].self, from: data) else {
            return []
        }
        return metadata
    }
    
    private func saveArtworkMetadata(_ metadata: [ArtworkMetadata]) {
        do {
            let data = try JSONEncoder().encode(metadata)
            userDefaults.set(data, forKey: UserDefaultsKeys.artworkMetadata)
        } catch {
            logger.log("Failed to save artwork metadata: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - Comparable conformance for metadata sorting

extension ArtworkMetadata: Comparable {
    static func < (lhs: ArtworkMetadata, rhs: ArtworkMetadata) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
    
    static func == (lhs: ArtworkMetadata, rhs: ArtworkMetadata) -> Bool {
        lhs.songId == rhs.songId
    }
}
