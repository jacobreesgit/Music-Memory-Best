import Foundation

protocol SettingsServiceProtocol {
    func clearAllLocalTrackingData()
    func getLocalTrackingDataSize() -> String
}

class SettingsService: SettingsServiceProtocol {
    private let logger: LoggerProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    
    init(
        logger: LoggerProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol,
        rankHistoryService: RankHistoryServiceProtocol,
        enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    ) {
        self.logger = logger
        self.artworkPersistenceService = artworkPersistenceService
        self.rankHistoryService = rankHistoryService
        self.enhancedSongCacheService = enhancedSongCacheService
    }
    
    func clearAllLocalTrackingData() {
        logger.log("Starting to clear all local tracking data", level: .info)
        
        // Clear all local play counts
        clearLocalPlayCounts()
        
        // Clear all rank history snapshots
        clearRankHistoryData()
        
        // Clear saved artwork
        artworkPersistenceService.clearSavedArtwork()
        
        // Clear enhanced song cache
        enhancedSongCacheService.clearEnhancedSongCache()
        
        // Clear MusicKit search cache
        clearMusicKitSearchCache()
        
        // Clear all artwork cache
        clearAllArtworkCache()
        
        // Clear any remaining app-specific UserDefaults keys
        clearRemainingAppData()
        
        logger.log("Successfully cleared all local tracking data", level: .info)
    }
    
    func getLocalTrackingDataSize() -> String {
        var totalSize: Int64 = 0
        
        // Calculate size of UserDefaults data
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Count local play count keys
        let playCountKeys = allKeys.filter { $0.hasPrefix("localPlayCount_") || $0.hasPrefix("baselinePlayCount_") }
        
        // Count rank history keys
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        
        // Count enhanced song cache keys
        let enhancedSongKeys = allKeys.filter { $0.hasPrefix("enhancedSong_") }
        
        // Count MusicKit search cache keys
        let musicKitSearchKeys = allKeys.filter { $0.hasPrefix("musicKitSearch_") }
        
        // Count artwork cache keys
        let artworkKeys = allKeys.filter { $0.hasPrefix("artwork_") }
        
        // Calculate actual data sizes for UserDefaults entries
        for key in playCountKeys + rankHistoryKeys + enhancedSongKeys + musicKitSearchKeys + artworkKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += Int64(data.count)
            } else if userDefaults.object(forKey: key) != nil {
                // Estimate size for non-data objects (integers, strings, etc.)
                totalSize += 50 // Conservative estimate
            }
        }
        
        // Add metadata sizes
        let metadataKeys = [
            UserDefaultsKeys.enhancedSongMetadata,
            UserDefaultsKeys.musicKitSearchMetadata,
            UserDefaultsKeys.artworkMetadata,
            UserDefaultsKeys.savedArtworkSongId,
            UserDefaultsKeys.savedArtworkTimestamp,
            UserDefaultsKeys.cacheLastCleanupDate
        ]
        
        for key in metadataKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += Int64(data.count)
            } else if userDefaults.object(forKey: key) != nil {
                totalSize += 50 // Conservative estimate
            }
        }
        
        // Format size
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        
        let sizeString = formatter.string(fromByteCount: totalSize)
        
        // Log breakdown for debugging
        logger.log("Data size breakdown - Play counts: \(playCountKeys.count), Rank history: \(rankHistoryKeys.count), Enhanced songs: \(enhancedSongKeys.count), MusicKit cache: \(musicKitSearchKeys.count), Artwork: \(artworkKeys.count), Total size: \(sizeString)", level: .debug)
        
        return sizeString
    }
    
    private func clearLocalPlayCounts() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove all local play count keys
        let playCountKeys = allKeys.filter {
            $0.hasPrefix("localPlayCount_") || $0.hasPrefix("baselinePlayCount_")
        }
        
        for key in playCountKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        logger.log("Cleared \(playCountKeys.count) local play count entries", level: .info)
    }
    
    private func clearRankHistoryData() {
        rankHistoryService.clearAllRankHistory()
    }
    
    private func clearMusicKitSearchCache() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove all MusicKit search cache keys
        let musicKitSearchKeys = allKeys.filter { $0.hasPrefix("musicKitSearch_") }
        
        for key in musicKitSearchKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove MusicKit search metadata
        userDefaults.removeObject(forKey: UserDefaultsKeys.musicKitSearchMetadata)
        
        logger.log("Cleared \(musicKitSearchKeys.count) MusicKit search cache entries", level: .info)
    }
    
    private func clearAllArtworkCache() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove all artwork cache keys
        let artworkKeys = allKeys.filter { $0.hasPrefix("artwork_") }
        
        for key in artworkKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove artwork metadata
        userDefaults.removeObject(forKey: UserDefaultsKeys.artworkMetadata)
        
        logger.log("Cleared \(artworkKeys.count) artwork cache entries", level: .info)
    }
    
    private func clearRemainingAppData() {
        let userDefaults = UserDefaults.standard
        
        // Clear all remaining app-specific UserDefaults keys
        let keysToRemove = [
            UserDefaultsKeys.enhancedSongMetadata,
            UserDefaultsKeys.savedArtworkSongId,
            UserDefaultsKeys.savedArtworkTimestamp,
            UserDefaultsKeys.cacheLastCleanupDate
        ]
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        // Perform a comprehensive cleanup of any missed keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        var additionalKeys: [String] = []
        
        for prefix in UserDefaultsKeys.allKeyPrefixes {
            let matchingKeys = allKeys.filter { $0.hasPrefix(prefix) }
            additionalKeys.append(contentsOf: matchingKeys)
        }
        
        // Remove any additional keys found
        for key in additionalKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        if !additionalKeys.isEmpty {
            logger.log("Cleared \(additionalKeys.count) additional app data entries", level: .info)
        }
        
        logger.log("Cleared remaining app metadata and any missed entries", level: .info)
    }
    
    // MARK: - Helper Methods for Individual Cache Sizes
    
    func getPlayCountCacheSize() -> String {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let playCountKeys = allKeys.filter { $0.hasPrefix("localPlayCount_") || $0.hasPrefix("baselinePlayCount_") }
        
        // Each play count entry is small (integer), estimate 50 bytes per entry
        let estimatedSize = playCountKeys.count * 50
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(estimatedSize))
    }
    
    func getRankHistoryCacheSize() -> String {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        
        var totalSize = 0
        for key in rankHistoryKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    func getEnhancedSongCacheSize() -> String {
        return enhancedSongCacheService.getEnhancedSongCacheSize()
    }
    
    func getArtworkCacheSize() -> String {
        return artworkPersistenceService.getArtworkCacheSize()
    }
    
    func getMusicKitSearchCacheSize() -> String {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let musicKitSearchKeys = allKeys.filter { $0.hasPrefix("musicKitSearch_") }
        
        var totalSize = 0
        for key in musicKitSearchKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
}
