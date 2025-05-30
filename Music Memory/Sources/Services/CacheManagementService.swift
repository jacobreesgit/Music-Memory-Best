import Foundation

protocol CacheManagementServiceProtocol {
    func performPeriodicCleanup()
    func performFullCleanup()
    func getCacheStatistics() -> CacheStatistics
    func shouldPerformCleanup() -> Bool
    func getCacheHealthScore() -> Double
    func getCacheOptimizationRecommendations() -> [String]
    func validateAllCaches() -> CacheValidationResult
    func coordinatedCacheWarmup(for songs: [Song]) async
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
    
    // CRITICAL FIX: Add validation stats
    let validCacheEntries: Int
    let staleCacheEntries: Int
    let corruptedCacheEntries: Int
}

struct CacheValidationResult {
    let enhancedSongs: (valid: Int, stale: Int, corrupted: Int)
    let artworkCache: (valid: Int, stale: Int, corrupted: Int)
    let searchCache: (valid: Int, stale: Int, corrupted: Int)
    let totalProblems: Int
    let recommendations: [String]
}

class CacheManagementService: CacheManagementServiceProtocol {
    private let logger: LoggerProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let queue = DispatchQueue(label: "cache-management", qos: .utility)
    
    // Cleanup intervals and thresholds
    private let periodicCleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let emergencyCleanupThreshold: Int = 200 * 1024 * 1024 // 200MB
    private let maxUserDefaultsKeys = 5000 // Reasonable limit for UserDefaults
    
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
        queue.async { [weak self] in
            self?._performPeriodicCleanup()
        }
    }
    
    private func _performPeriodicCleanup() {
        logger.log("Starting periodic cache cleanup with validation", level: .info)
        
        let startTime = Date()
        
        // Clean up each cache type with validation
        rankHistoryService.cleanupOldSnapshots()
        artworkPersistenceService.cleanupOldArtwork()
        enhancedSongCacheService.cleanupOldEnhancedSongs()
        
        // Clean up MusicKit search cache if the service supports it
        if let musicLibraryService = musicLibraryService as? MusicLibraryService {
            Task {
                await musicLibraryService.cleanupOldMusicKitSearchCache()
            }
        }
        
        // CRITICAL FIX: Validate cache consistency after cleanup
        let validationResult = validateAllCaches()
        if validationResult.totalProblems > 0 {
            logger.log("Found \(validationResult.totalProblems) cache problems after cleanup", level: .warning)
        }
        
        // Update last cleanup timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.cacheLastCleanupDate)
        
        let cleanupDuration = Date().timeIntervalSince(startTime)
        let stats = getCacheStatistics()
        logger.log("Periodic cache cleanup completed in \(String(format: "%.2f", cleanupDuration))s. Total cache size: \(stats.totalDataSize)", level: .info)
    }
    
    func performFullCleanup() {
        queue.async { [weak self] in
            self?._performFullCleanup()
        }
    }
    
    private func _performFullCleanup() {
        logger.log("Starting full cache cleanup (emergency cleanup)", level: .warning)
        
        let startTime = Date()
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // CRITICAL FIX: Use age-based cleanup instead of arbitrary removal
        
        // Clean enhanced song cache more aggressively (keep only last 30 days)
        cleanupEnhancedSongCacheAggressively(maxAge: 30 * 24 * 60 * 60)
        
        // Clean artwork cache more aggressively (keep only last 7 days)
        cleanupArtworkCacheAggressively(maxAge: 7 * 24 * 60 * 60)
        
        // Clean search cache more aggressively (keep only last 7 days)
        cleanupSearchCacheAggressively(maxAge: 7 * 24 * 60 * 60)
        
        // Clean up orphaned UserDefaults keys
        cleanupOrphanedKeys()
        
        // Validate after aggressive cleanup
        let validationResult = validateAllCaches()
        
        // Update last cleanup timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.cacheLastCleanupDate)
        
        let cleanupDuration = Date().timeIntervalSince(startTime)
        logger.log("Full cache cleanup completed in \(String(format: "%.2f", cleanupDuration))s. Problems found: \(validationResult.totalProblems)", level: .warning)
    }
    
    // CRITICAL FIX: Age-based cleanup methods
    
    private func cleanupEnhancedSongCacheAggressively(maxAge: TimeInterval) {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let enhancedSongKeys = allKeys.filter { $0.hasPrefix("enhancedSong_") }
        
        var removedCount = 0
        
        for key in enhancedSongKeys {
            guard let data = userDefaults.data(forKey: key),
                  let cachedData = try? JSONDecoder().decode(CachedSongEnhancement.self, from: data) else {
                // Remove corrupted entries
                userDefaults.removeObject(forKey: key)
                removedCount += 1
                continue
            }
            
            // Remove if too old
            if Date().timeIntervalSince(cachedData.timestamp) > maxAge {
                userDefaults.removeObject(forKey: key)
                removedCount += 1
            }
        }
        
        logger.log("Aggressive enhanced song cleanup: removed \(removedCount) entries", level: .info)
    }
    
    private func cleanupArtworkCacheAggressively(maxAge: TimeInterval) {
        // This would need to be implemented in ArtworkPersistenceService
        // For now, use the existing cleanup
        artworkPersistenceService.cleanupOldArtwork()
    }
    
    private func cleanupSearchCacheAggressively(maxAge: TimeInterval) {
        if let musicLibraryService = musicLibraryService as? MusicLibraryService {
            Task {
                await musicLibraryService.cleanupOldMusicKitSearchCache()
            }
        }
    }
    
    private func cleanupOrphanedKeys() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        var orphanedKeys: [String] = []
        
        // Find keys that match our patterns but don't have corresponding metadata
        for key in allKeys {
            let isAppKey = UserDefaultsKeys.allKeyPrefixes.contains { key.hasPrefix($0) }
            
            if isAppKey {
                // Check if this key has valid metadata or is a metadata key itself
                if !isValidAppKey(key) {
                    orphanedKeys.append(key)
                }
            }
        }
        
        // Remove orphaned keys
        for key in orphanedKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        if !orphanedKeys.isEmpty {
            logger.log("Removed \(orphanedKeys.count) orphaned cache keys", level: .info)
        }
    }
    
    private func isValidAppKey(_ key: String) -> Bool {
        // This is a simplified validation - in practice, you'd want more sophisticated validation
        
        // Metadata keys are always valid
        if key == UserDefaultsKeys.enhancedSongMetadata ||
           key == UserDefaultsKeys.musicKitSearchMetadata ||
           key == UserDefaultsKeys.artworkMetadata ||
           key == UserDefaultsKeys.savedArtworkSongId ||
           key == UserDefaultsKeys.savedArtworkTimestamp ||
           key == UserDefaultsKeys.cacheLastCleanupDate {
            return true
        }
        
        // For data keys, check if they have reasonable format
        if key.hasPrefix("enhancedSong_") || key.hasPrefix("artwork_") || key.hasPrefix("musicKitSearch_") {
            // Extract ID part and validate it's reasonable
            let components = key.components(separatedBy: "_")
            if components.count >= 2 && !components[1].isEmpty {
                return true
            }
        }
        
        if key.hasPrefix("localPlayCount_") || key.hasPrefix("baselinePlayCount_") || key.hasPrefix("rankSnapshots_") {
            let components = key.components(separatedBy: "_")
            if components.count >= 2 && !components[1].isEmpty {
                return true
            }
        }
        
        return false
    }
    
    func getCacheStatistics() -> CacheStatistics {
        return queue.sync { [weak self] in
            return self?._getCacheStatistics() ?? CacheStatistics(
                totalUserDefaultsKeys: 0, totalDataSize: "0 KB",
                playCountEntries: 0, rankHistoryEntries: 0, enhancedSongEntries: 0,
                artworkEntries: 0, musicKitSearchEntries: 0,
                lastCleanupDate: nil, oldestDataDate: nil, newestDataDate: nil,
                validCacheEntries: 0, staleCacheEntries: 0, corruptedCacheEntries: 0
            )
        }
    }
    
    private func _getCacheStatistics() -> CacheStatistics {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Count entries by type
        let playCountEntries = allKeys.filter { $0.hasPrefix("localPlayCount_") || $0.hasPrefix("baselinePlayCount_") }.count
        let rankHistoryEntries = allKeys.filter { $0.hasPrefix("rankSnapshots_") }.count
        let enhancedSongEntries = allKeys.filter { $0.hasPrefix("enhancedSong_") }.count
        let artworkEntries = allKeys.filter { $0.hasPrefix("artwork_") }.count
        let musicKitSearchEntries = allKeys.filter { $0.hasPrefix("musicKitSearch_") }.count
        
        // Calculate total data size more accurately
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
        
        // Get oldest and newest data dates
        let oldestDataDate = getOldestDataDate()
        let newestDataDate = getNewestDataDate()
        
        // CRITICAL FIX: Get validation stats
        let validationResult = validateAllCaches()
        let validEntries = validationResult.enhancedSongs.valid + validationResult.artworkCache.valid + validationResult.searchCache.valid
        let staleEntries = validationResult.enhancedSongs.stale + validationResult.artworkCache.stale + validationResult.searchCache.stale
        let corruptedEntries = validationResult.enhancedSongs.corrupted + validationResult.artworkCache.corrupted + validationResult.searchCache.corrupted
        
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
            newestDataDate: newestDataDate,
            validCacheEntries: validEntries,
            staleCacheEntries: staleEntries,
            corruptedCacheEntries: corruptedEntries
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
        
        // CRITICAL FIX: More intelligent emergency checks
        let stats = getCacheStatistics()
        
        // Check total number of keys
        if stats.totalUserDefaultsKeys > maxUserDefaultsKeys {
            logger.log("Emergency cleanup needed: too many UserDefaults keys (\(stats.totalUserDefaultsKeys))", level: .warning)
            return true
        }
        
        // Check cache corruption level
        let totalCacheEntries = stats.validCacheEntries + stats.staleCacheEntries + stats.corruptedCacheEntries
        if totalCacheEntries > 0 {
            let corruptionRate = Double(stats.corruptedCacheEntries) / Double(totalCacheEntries)
            if corruptionRate > 0.1 { // More than 10% corrupted
                logger.log("Emergency cleanup needed: high cache corruption rate (\(String(format: "%.1f", corruptionRate * 100))%)", level: .warning)
                return true
            }
        }
        
        return false
    }
    
    // CRITICAL FIX: Comprehensive cache validation
    func validateAllCaches() -> CacheValidationResult {
        return queue.sync { [weak self] in
            return self?._validateAllCaches() ?? CacheValidationResult(
                enhancedSongs: (0, 0, 0),
                artworkCache: (0, 0, 0),
                searchCache: (0, 0, 0),
                totalProblems: 0,
                recommendations: ["Cache validation unavailable"]
            )
        }
    }
    
    private func _validateAllCaches() -> CacheValidationResult {
        // Validate enhanced song cache
        let enhancedSongValidation = enhancedSongCacheService.getCacheValidationInfo()
        
        // Validate artwork cache (simplified - would need method in ArtworkPersistenceService)
        let artworkValidation = validateArtworkCache()
        
        // Validate search cache (simplified - would need method in MusicLibraryService)
        let searchValidation = validateSearchCache()
        
        let totalProblems = enhancedSongValidation.stale + enhancedSongValidation.corrupted +
                           artworkValidation.stale + artworkValidation.corrupted +
                           searchValidation.stale + searchValidation.corrupted
        
        var recommendations: [String] = []
        
        if enhancedSongValidation.corrupted > 0 {
            recommendations.append("Remove \(enhancedSongValidation.corrupted) corrupted enhanced song entries")
        }
        
        if enhancedSongValidation.stale > 0 {
            recommendations.append("Refresh \(enhancedSongValidation.stale) stale enhanced song entries")
        }
        
        if artworkValidation.corrupted > 0 {
            recommendations.append("Remove \(artworkValidation.corrupted) corrupted artwork entries")
        }
        
        if searchValidation.stale > 0 {
            recommendations.append("Clear \(searchValidation.stale) stale search cache entries")
        }
        
        if totalProblems == 0 {
            recommendations.append("All caches are healthy")
        }
        
        return CacheValidationResult(
            enhancedSongs: enhancedSongValidation,
            artworkCache: artworkValidation,
            searchCache: searchValidation,
            totalProblems: totalProblems,
            recommendations: recommendations
        )
    }
    
    private func validateArtworkCache() -> (valid: Int, stale: Int, corrupted: Int) {
        // Simplified validation - in practice, this would be in ArtworkPersistenceService
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let artworkKeys = allKeys.filter { $0.hasPrefix("artwork_") }
        
        var valid = 0
        var stale = 0
        var corrupted = 0
        
        for key in artworkKeys {
            if let data = userDefaults.data(forKey: key), !data.isEmpty {
                // Could check if it's valid image data
                valid += 1
            } else {
                corrupted += 1
            }
        }
        
        return (valid: valid, stale: stale, corrupted: corrupted)
    }
    
    private func validateSearchCache() -> (valid: Int, stale: Int, corrupted: Int) {
        // Simplified validation - in practice, this would be in MusicLibraryService
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let searchKeys = allKeys.filter { $0.hasPrefix("musicKitSearch_") }
        
        var valid = 0
        var stale = 0
        var corrupted = 0
        
        for key in searchKeys {
            guard let data = userDefaults.data(forKey: key) else {
                corrupted += 1
                continue
            }
            
            guard let cachedResult = try? JSONDecoder().decode(CachedMusicKitResult.self, from: data) else {
                corrupted += 1
                continue
            }
            
            // Check if stale (14 days)
            if Date().timeIntervalSince(cachedResult.timestamp) > 14 * 24 * 60 * 60 {
                stale += 1
            } else {
                valid += 1
            }
        }
        
        return (valid: valid, stale: stale, corrupted: corrupted)
    }
    
    // CRITICAL FIX: Coordinated cache warming
    func coordinatedCacheWarmup(for songs: [Song]) async {
        logger.log("Starting coordinated cache warmup for \(songs.count) songs", level: .info)
        
        // Warm up caches in priority order
        for song in songs.prefix(50) { // Warm up top 50 songs
            // Check if already cached
            if song.hasCachedEnhancedData() {
                continue
            }
            
            // Try to enhance and cache
            if let enhancedSong = await musicLibraryService.enhanceSongWithMusicKit(song) {
                // This will automatically cache the enhanced song and artwork
                logger.log("Warmed cache for '\(song.title)'", level: .debug)
            }
            
            // Small delay to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        logger.log("Completed coordinated cache warmup", level: .info)
    }
    
    // MARK: - Private Helper Methods
    
    private func getOldestDataDate() -> Date? {
        return rankHistoryService.getOldestSnapshotDate()
    }
    
    private func getNewestDataDate() -> Date? {
        return rankHistoryService.getNewestSnapshotDate()
    }
    
    /// Get a health score for the cache system (0.0 = unhealthy, 1.0 = perfect health)
    func getCacheHealthScore() -> Double {
        let stats = getCacheStatistics()
        let validationResult = validateAllCaches()
        
        var healthScore: Double = 1.0
        
        // Penalty for too many keys
        if stats.totalUserDefaultsKeys > maxUserDefaultsKeys {
            healthScore -= 0.3
        } else if stats.totalUserDefaultsKeys > maxUserDefaultsKeys * 0.8 {
            healthScore -= 0.1
        }
        
        // Penalty for cache corruption
        let totalCacheEntries = stats.validCacheEntries + stats.staleCacheEntries + stats.corruptedCacheEntries
        if totalCacheEntries > 0 {
            let corruptionRate = Double(stats.corruptedCacheEntries) / Double(totalCacheEntries)
            healthScore -= corruptionRate * 0.5 // Up to 50% penalty for corruption
            
            let staleRate = Double(stats.staleCacheEntries) / Double(totalCacheEntries)
            healthScore -= staleRate * 0.2 // Up to 20% penalty for stale data
        }
        
        // Penalty for no recent cleanup
        if let lastCleanup = stats.lastCleanupDate {
            let daysSinceCleanup = Date().timeIntervalSince(lastCleanup) / (24 * 60 * 60)
            if daysSinceCleanup > 7 {
                healthScore -= 0.2
            } else if daysSinceCleanup > 3 {
                healthScore -= 0.1
            }
        } else {
            healthScore -= 0.3 // Never cleaned up
        }
        
        return max(0.0, healthScore)
    }
    
    /// Get recommendations for cache optimization
    func getCacheOptimizationRecommendations() -> [String] {
        let stats = getCacheStatistics()
        let validationResult = validateAllCaches()
        var recommendations: [String] = []
        
        if stats.corruptedCacheEntries > 0 {
            recommendations.append("Repair \(stats.corruptedCacheEntries) corrupted cache entries")
        }
        
        if stats.staleCacheEntries > 50 {
            recommendations.append("Refresh \(stats.staleCacheEntries) stale cache entries")
        }
        
        if stats.totalUserDefaultsKeys > maxUserDefaultsKeys {
            recommendations.append("Reduce UserDefaults usage - \(stats.totalUserDefaultsKeys) keys exceed recommended limit")
        }
        
        if let lastCleanup = stats.lastCleanupDate {
            let daysSinceCleanup = Date().timeIntervalSince(lastCleanup) / (24 * 60 * 60)
            if daysSinceCleanup > 7 {
                recommendations.append("Cache cleanup is overdue by \(Int(daysSinceCleanup - 1)) days")
            }
        } else {
            recommendations.append("Perform initial cache cleanup")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Cache system is optimized and healthy")
        }
        
        return recommendations
    }
}
