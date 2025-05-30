import Foundation
import UIKit
import MediaPlayer

protocol ArtworkPersistenceServiceProtocol {
    func saveCurrentArtwork(songId: String, artwork: UIImage?)
    func loadSavedArtwork(for songId: String) -> UIImage?
    func clearSavedArtwork()
    func cleanupOldArtwork()
    func getArtworkCacheSize() -> String
}

/// Metadata for tracking artwork cache
struct ArtworkMetadata: Codable {
    let songId: String
    let timestamp: Date
    let dataSize: Int
}

class ArtworkPersistenceService: ArtworkPersistenceServiceProtocol {
    private let logger: LoggerProtocol
    private let userDefaults = UserDefaults.standard
    private let artworkMaxAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxArtworkCacheSize: Int = 50 * 1024 * 1024 // 50MB limit for artwork cache
    private let artworkCompressionQuality: CGFloat = 0.6 // Balanced quality/size
    private let maxCachedArtworks = 100 // Limit number of cached artworks
    
    init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    func saveCurrentArtwork(songId: String, artwork: UIImage?) {
        guard let artwork = artwork else {
            logger.log("No artwork to save for song ID: \(songId)", level: .debug)
            return
        }
        
        logger.log("Saving artwork to UserDefaults for song ID: \(songId)", level: .info)
        
        // Resize artwork to reasonable size before compression
        let resizedArtwork = resizeImage(artwork, targetSize: CGSize(width: 300, height: 300))
        
        // Convert image to data with compression
        guard let imageData = resizedArtwork.jpegData(compressionQuality: artworkCompressionQuality) else {
            logger.log("Failed to convert artwork to data for song ID: \(songId)", level: .error)
            return
        }
        
        // Check if adding this artwork would exceed cache size limits
        if shouldSkipCaching(newDataSize: imageData.count) {
            logger.log("Skipping artwork cache for song ID: \(songId) - cache size limit reached", level: .warning)
            return
        }
        
        let key = UserDefaultsKeys.artworkKey(for: songId)
        userDefaults.set(imageData, forKey: key)
        
        // Update metadata for cache management
        updateArtworkMetadata(songId: songId, dataSize: imageData.count)
        
        // Save currently saved artwork info
        userDefaults.set(songId, forKey: UserDefaultsKeys.savedArtworkSongId)
        userDefaults.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.savedArtworkTimestamp)
        
        logger.log("Successfully saved artwork for song ID: \(songId) (\(imageData.count) bytes)", level: .info)
    }
    
    func loadSavedArtwork(for songId: String) -> UIImage? {
        // Check if we have saved artwork for this song
        guard let savedSongId = userDefaults.string(forKey: UserDefaultsKeys.savedArtworkSongId),
              savedSongId == songId else {
            logger.log("No saved artwork found for song ID: \(songId)", level: .debug)
            return nil
        }
        
        // Check if the saved artwork is not too old
        let savedTimestamp = userDefaults.double(forKey: UserDefaultsKeys.savedArtworkTimestamp)
        let age = Date().timeIntervalSince1970 - savedTimestamp
        
        if age > artworkMaxAge {
            logger.log("Saved artwork is too old (\(Int(age / 3600)) hours), clearing it", level: .info)
            clearSavedArtwork()
            return nil
        }
        
        // Load the artwork data
        let key = UserDefaultsKeys.artworkKey(for: songId)
        guard let imageData = userDefaults.data(forKey: key),
              let image = UIImage(data: imageData) else {
            logger.log("Failed to load saved artwork from UserDefaults for song ID: \(songId)", level: .warning)
            clearSavedArtwork()
            return nil
        }
        
        logger.log("Successfully loaded saved artwork for song ID: \(songId)", level: .info)
        return image
    }
    
    func clearSavedArtwork() {
        // Clear the currently saved artwork
        if let savedSongId = userDefaults.string(forKey: UserDefaultsKeys.savedArtworkSongId) {
            let key = UserDefaultsKeys.artworkKey(for: savedSongId)
            userDefaults.removeObject(forKey: key)
            
            // Remove from metadata
            removeFromArtworkMetadata(songId: savedSongId)
            
            logger.log("Cleared saved artwork for song ID: \(savedSongId)", level: .debug)
        }
        
        // Clear metadata
        userDefaults.removeObject(forKey: UserDefaultsKeys.savedArtworkSongId)
        userDefaults.removeObject(forKey: UserDefaultsKeys.savedArtworkTimestamp)
        
        logger.log("Cleared saved artwork metadata", level: .debug)
    }
    
    func cleanupOldArtwork() {
        var metadata = getArtworkMetadata()
        let oldEntries = metadata.filter { Date().timeIntervalSince($0.timestamp) > artworkMaxAge }
        
        // Remove old artwork entries
        for entry in oldEntries {
            let key = UserDefaultsKeys.artworkKey(for: entry.songId)
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove old entries from metadata
        metadata.removeAll { oldEntries.contains($0) }
        
        // If we have too many artworks, remove oldest ones
        if metadata.count > maxCachedArtworks {
            let sortedMetadata = metadata.sorted { $0.timestamp < $1.timestamp }
            let toRemove = sortedMetadata.prefix(metadata.count - maxCachedArtworks)
            
            for entry in toRemove {
                let key = UserDefaultsKeys.artworkKey(for: entry.songId)
                userDefaults.removeObject(forKey: key)
            }
            
            metadata = Array(sortedMetadata.suffix(maxCachedArtworks))
        }
        
        // Check total cache size and remove entries if needed
        metadata = enforceArtworkCacheSizeLimit(metadata: metadata)
        
        // Save updated metadata
        saveArtworkMetadata(metadata)
        
        if !oldEntries.isEmpty {
            logger.log("Cleaned up \(oldEntries.count) old artwork cache entries", level: .debug)
        }
    }
    
    func getArtworkCacheSize() -> String {
        let metadata = getArtworkMetadata()
        let totalSize = metadata.reduce(0) { $0 + $1.dataSize }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    // MARK: - Private Methods
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
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
    
    private func enforceArtworkCacheSizeLimit(metadata: [ArtworkMetadata]) -> [ArtworkMetadata] {
        var sortedMetadata = metadata.sorted { $0.timestamp > $1.timestamp } // Newest first
        let targetSize = Int(Double(maxArtworkCacheSize) * 0.8) // Keep cache at 80% of limit
        
        var currentSize = 0
        var validMetadata: [ArtworkMetadata] = []
        
        for entry in sortedMetadata {
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
    
    private func updateArtworkMetadata(songId: String, dataSize: Int) {
        var metadata = getArtworkMetadata()
        
        // Remove existing entry if present
        metadata.removeAll { $0.songId == songId }
        
        // Add new entry
        metadata.append(ArtworkMetadata(
            songId: songId,
            timestamp: Date(),
            dataSize: dataSize
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
