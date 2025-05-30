import Foundation

protocol CacheManagementServiceProtocol {
    func performPeriodicCleanup()
    func performFullCleanup()
    func getCacheStatistics() -> CacheStatistics
    func shouldPerformCleanup() -> Bool
    func getCacheHealthScore() -> Double
    func getCacheOptimizationRecommendations() -> [String]
}

struct CacheStatistics {
    let totalUserDefaultsKeys: Int
    let totalDataSize: String
    let playCountEntries: Int
    let rankHistoryEntries: Int
    let enhancedSongEntries: Int
    let artworkEntries: Int
    let musicKitSearchEntries: Int
    let lastCleanupDate: Date?
    let oldestDataDate: Date?
    let newestDataDate: Date?
}

class CacheManagementService: CacheManagementServiceProtocol {
    private let logger: LoggerProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    private let musicLibraryService: MusicLibraryServiceProtocol
    
    // Cleanup intervals
    private let periodicCleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let emergencyCleanupThreshold: Int = 100 * 1024 * 1024 // 100MB
    
    init(
        logger: LoggerProtocol,
        rankHistoryService: RankHistoryServiceProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol,
        enhancedSongCacheService: EnhancedSongCacheServiceProtocol,
        musicLibraryService: MusicLibraryServiceProtocol
    ) {
        self.logger = logger
        self.rankHistoryService = rankHistoryService
        self.artworkPersistenceService = artworkPersistenceService
        self.enhancedSongCacheService = enhancedSongCacheService
        self.musicLibraryService = musicLibraryService
    }
    
    func performPeriodicCleanup() {
        logger.log("Starting periodic cache cleanup", level: .info)
        
        // Clean up each cache type
        rankHistoryService.cleanupOldSnapshots()
        artworkPersistenceService.cleanupOldArtwork()
        enhancedSongCacheService.cleanupOldEnhancedSongs()
        
        // Clean up MusicKit search cache if the service supports it
        if let musicLibraryService = musicLibraryService as? MusicLibraryService {
            Task {
                await musicLibraryService.cleanupOldMusicKitSearchCache()
            }
        }
        
        // Update last cleanup timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.cacheLastCleanupDate)
        
        let stats = getCacheStatistics()
        logger.log("Periodic cache cleanup completed. Total cache size: \(stats.totalDataSize)", level: .info)
    }
    
    func performFullCleanup() {
        logger.log("Starting full cache cleanup (emergency cleanup)", level: .warning)
        
        // More aggressive cleanup for emergency situations
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove old artwork entries more aggressively
        let artworkKeys = allKeys.filter { $0.hasPrefix("artwork_") }
        var removedArtworkCount = 0
        
        // Remove older artwork entries first (keep only recent 25 instead of 100)
        if artworkKeys.count > 25 {
            // This is a simplified approach - in a real implementation,
            // we'd sort by timestamp and remove oldest entries
            let keysToRemove = artworkKeys.prefix(artworkKeys.count - 25)
            for key in keysToRemove {
                userDefaults.removeObject(forKey: key)
                removedArtworkCount += 1
            }
        }
        
        // Remove old enhanced song cache entries
        let enhancedSongKeys = allKeys.filter { $0.hasPrefix("enhancedSong_") }
        var removedEnhancedSongCount = 0
        
        if enhancedSongKeys.count > 500 {
            let keysToRemove = enhancedSongKeys.prefix(enhancedSongKeys.count - 500)
            for key in keysToRemove {
                userDefaults.removeObject(forKey: key)
                removedEnhancedSongCount += 1
            }
        }
        
        // Remove old MusicKit search cache entries
        let musicKitSearchKeys = allKeys.filter { $0.hasPrefix("musicKitSearch_") }
        var removedSearchCount = 0
        
        if musicKitSearchKeys.count > 250 {
            let keysToRemove = musicKitSearchKeys.prefix(musicKitSearchKeys.count - 250)
            for key in keysToRemove {
                userDefaults.removeObject(forKey: key)
                removedSearchCount += 1
            }
        }
        
        // Clean up metadata for removed entries
        artworkPersistenceService.cleanupOldArtwork()
        enhancedSongCacheService.cleanupOldEnhancedSongs()
        
        // Update last cleanup timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.cacheLastCleanupDate)
        
        logger.log("Full cache cleanup completed. Removed: \(removedArtworkCount) artwork, \(removedEnhancedSongCount) enhanced songs, \(removedSearchCount) search entries", level: .warning)
    }
    
    func getCacheStatistics() -> CacheStatistics {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Count entries by type
        let playCountEntries = allKeys.filter { $0.hasPrefix("localPlayCount_") || $0.hasPrefix("baselinePlayCount_") }.count
        let rankHistoryEntries = allKeys.filter { $0.hasPrefix("rankSnapshots_") }.count
        let enhancedSongEntries = allKeys.filter { $0.hasPrefix("enhancedSong_") }.count
        let artworkEntries = allKeys.filter { $0.hasPrefix("artwork_") }.count
        let musicKitSearchEntries = allKeys.filter { $0.hasPrefix("musicKitSearch_") }.count
        
        // Calculate total data size
        var totalSize: Int64 = 0
        let relevantKeys = allKeys.filter { key in
            UserDefaultsKeys.allKeyPrefixes.contains { key.hasPrefix($0) } ||
            UserDefaultsKeys.allKeyPrefixes.contains(key)
        }
        
        for key in relevantKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += Int64(data.count)
            } else if userDefaults.object(forKey: key) != nil {
                totalSize += 50 // Estimate for non-data objects
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        let totalSizeString = formatter.string(fromByteCount: totalSize)
        
        // Get last cleanup date
        let lastCleanupTimestamp = userDefaults.double(forKey: UserDefaultsKeys.cacheLastCleanupDate)
        let lastCleanupDate = lastCleanupTimestamp > 0 ? Date(timeIntervalSince1970: lastCleanupTimestamp) : nil
        
        // Get oldest and newest data dates (simplified approach)
        let oldestDataDate = getOldestDataDate()
        let newestDataDate = getNewestDataDate()
        
        return CacheStatistics(
            totalUserDefaultsKeys: relevantKeys.count,
            totalDataSize: totalSizeString,
            playCountEntries: playCountEntries,
            rankHistoryEntries: rankHistoryEntries,
            enhancedSongEntries: enhancedSongEntries,
            artworkEntries: artworkEntries,
            musicKitSearchEntries: musicKitSearchEntries,
            lastCleanupDate: lastCleanupDate,
            oldestDataDate: oldestDataDate,
            newestDataDate: newestDataDate
        )
    }
    
    func shouldPerformCleanup() -> Bool {
        let lastCleanupTimestamp = UserDefaults.standard.double(forKey: UserDefaultsKeys.cacheLastCleanupDate)
        
        if lastCleanupTimestamp == 0 {
            // Never cleaned up before
            return true
        }
        
        let lastCleanupDate = Date(timeIntervalSince1970: lastCleanupTimestamp)
        let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanupDate)
        
        if timeSinceLastCleanup >= periodicCleanupInterval {
            return true
        }
        
        // Check if we're approaching emergency cleanup thresholds
        let stats = getCacheStatistics()
        
        // Check total number of keys (rough emergency check)
        if stats.totalUserDefaultsKeys > 5000 {
            logger.log("Emergency cleanup needed: too many UserDefaults keys (\(stats.totalUserDefaultsKeys))", level: .warning)
            return true
        }
        
        // Check if we have excessive artwork entries
        if stats.artworkEntries > 200 {
            logger.log("Emergency cleanup needed: too many artwork entries (\(stats.artworkEntries))", level: .warning)
            return true
        }
        
        return false
    }
    
    // MARK: - Private Helper Methods
    
    private func getOldestDataDate() -> Date? {
        // This is a simplified implementation
        // In a real app, we'd check timestamps in metadata for each cache type
        return rankHistoryService.getOldestSnapshotDate()
    }
    
    private func getNewestDataDate() -> Date? {
        // This is a simplified implementation
        // In a real app, we'd check timestamps in metadata for each cache type
        return rankHistoryService.getNewestSnapshotDate()
    }
    
    // MARK: - Emergency Cleanup Methods
    
    func performEmergencyCleanupIfNeeded() {
        let stats = getCacheStatistics()
        
        // Emergency thresholds
        if stats.totalUserDefaultsKeys > 10000 || stats.artworkEntries > 500 || stats.enhancedSongEntries > 2000 {
            logger.log("Performing emergency cleanup due to excessive cache usage", level: .error)
            performFullCleanup()
        }
    }
    
    func estimateUserDefaultsSize() -> Int64 {
        // Estimate the total UserDefaults size for our app
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        var totalSize: Int64 = 0
        
        for key in allKeys {
            if UserDefaultsKeys.allKeyPrefixes.contains(where: { key.hasPrefix($0) }) ||
               UserDefaultsKeys.allKeyPrefixes.contains(key) {
                
                if let data = userDefaults.data(forKey: key) {
                    totalSize += Int64(data.count)
                } else if userDefaults.object(forKey: key) != nil {
                    totalSize += 50 // Conservative estimate
                }
            }
        }
        
        return totalSize
    }
    
    // MARK: - Protocol Required Methods
    
    /// Get a health score for the cache system (0.0 = unhealthy, 1.0 = perfect health)
    func getCacheHealthScore() -> Double {
        let stats = getCacheStatistics()
        
        var healthScore: Double = 1.0
        
        // Penalty for too many keys
        if stats.totalUserDefaultsKeys > 1000 {
            healthScore -= 0.2
        }
        
        // Penalty for excessive artwork cache
        if stats.artworkEntries > 100 {
            healthScore -= 0.3
        }
        
        // Penalty for no recent cleanup
        if let lastCleanup = stats.lastCleanupDate {
            let daysSinceCleanup = Date().timeIntervalSince(lastCleanup) / (24 * 60 * 60)
            if daysSinceCleanup > 7 {
                healthScore -= 0.2
            }
        } else {
            healthScore -= 0.4 // Never cleaned up
        }
        
        return max(0.0, healthScore)
    }
    
    /// Get recommendations for cache optimization
    func getCacheOptimizationRecommendations() -> [String] {
        let stats = getCacheStatistics()
        var recommendations: [String] = []
        
        if stats.artworkEntries > 100 {
            recommendations.append("Consider clearing some artwork cache to free up space")
        }
        
        if stats.enhancedSongEntries > 1000 {
            recommendations.append("Enhanced song cache is large - cleanup recommended")
        }
        
        if stats.lastCleanupDate == nil {
            recommendations.append("Perform initial cache cleanup")
        } else if let lastCleanup = stats.lastCleanupDate {
            let daysSinceCleanup = Date().timeIntervalSince(lastCleanup) / (24 * 60 * 60)
            if daysSinceCleanup > 7 {
                recommendations.append("Cache cleanup is overdue")
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append("Cache is healthy and optimized")
        }
        
        return recommendations
    }
}
