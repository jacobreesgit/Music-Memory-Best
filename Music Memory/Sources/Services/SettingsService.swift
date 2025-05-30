import Foundation

protocol SettingsServiceProtocol {
    func clearAllLocalTrackingData()
    func getLocalTrackingDataSize() -> String
    func getDetailedCacheBreakdown() -> CacheBreakdown
    func validateCacheIntegrity() -> CacheIntegrityReport
}

// CRITICAL FIX: Detailed cache breakdown structure
struct CacheBreakdown {
    let totalSize: String
    let playCountSize: String
    let rankHistorySize: String
    let enhancedSongSize: String
    let artworkSize: String
    let musicKitSearchSize: String
    
    let playCountEntries: Int
    let rankHistoryEntries: Int
    let enhancedSongEntries: Int
    let artworkEntries: Int
    let musicKitSearchEntries: Int
    
    let breakdown: [(name: String, size: String, entries: Int)]
    
    init(
        totalSize: String,
        playCountSize: String, playCountEntries: Int,
        rankHistorySize: String, rankHistoryEntries: Int,
        enhancedSongSize: String, enhancedSongEntries: Int,
        artworkSize: String, artworkEntries: Int,
        musicKitSearchSize: String, musicKitSearchEntries: Int
    ) {
        self.totalSize = totalSize
        self.playCountSize = playCountSize
        self.rankHistorySize = rankHistorySize
        self.enhancedSongSize = enhancedSongSize
        self.artworkSize = artworkSize
        self.musicKitSearchSize = musicKitSearchSize
        
        self.playCountEntries = playCountEntries
        self.rankHistoryEntries = rankHistoryEntries
        self.enhancedSongEntries = enhancedSongEntries
        self.artworkEntries = artworkEntries
        self.musicKitSearchEntries = musicKitSearchEntries
        
        self.breakdown = [
            ("Play Count Tracking", playCountSize, playCountEntries),
            ("Rank History", rankHistorySize, rankHistoryEntries),
            ("Enhanced Song Data", enhancedSongSize, enhancedSongEntries),
            ("Artwork Cache", artworkSize, artworkEntries),
            ("MusicKit Search Cache", musicKitSearchSize, musicKitSearchEntries)
        ]
    }
}

// CRITICAL FIX: Cache integrity reporting
struct CacheIntegrityReport {
    let totalEntries: Int
    let validEntries: Int
    let staleEntries: Int
    let corruptedEntries: Int
    let orphanedKeys: Int
    
    let enhancedSongIntegrity: (valid: Int, stale: Int, corrupted: Int)
    let artworkIntegrity: (valid: Int, stale: Int, corrupted: Int)
    let searchIntegrity: (valid: Int, stale: Int, corrupted: Int)
    
    let recommendations: [String]
    let healthScore: Double
    
    var hasProblems: Bool {
        return staleEntries > 0 || corruptedEntries > 0 || orphanedKeys > 0
    }
    
    var problemSummary: String {
        var problems: [String] = []
        
        if staleEntries > 0 {
            problems.append("\(staleEntries) stale")
        }
        
        if corruptedEntries > 0 {
            problems.append("\(corruptedEntries) corrupted")
        }
        
        if orphanedKeys > 0 {
            problems.append("\(orphanedKeys) orphaned")
        }
        
        if problems.isEmpty {
            return "All caches healthy"
        } else {
            return "Found: " + problems.joined(separator: ", ")
        }
    }
}

class SettingsService: SettingsServiceProtocol {
    private let logger: LoggerProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    private let queue = DispatchQueue(label: "settings-service", qos: .utility)
    
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
        logger.log("Starting comprehensive clear of all local tracking data", level: .info)
        
        let startTime = Date()
        
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
        
        // CRITICAL FIX: Perform thorough cleanup of orphaned keys
        performThoroughKeyCleanup()
        
        let duration = Date().timeIntervalSince(startTime)
        logger.log("Successfully cleared all local tracking data in \(String(format: "%.2f", duration))s", level: .info)
    }
    
    func getLocalTrackingDataSize() -> String {
        return queue.sync { [weak self] in
            return self?._getLocalTrackingDataSize() ?? "0 KB"
        }
    }
    
    private func _getLocalTrackingDataSize() -> String {
        var totalSize: Int64 = 0
        
        // Calculate size of UserDefaults data more accurately
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Get all app-related keys
        let appKeys = allKeys.filter { key in
            UserDefaultsKeys.allKeyPrefixes.contains { key.hasPrefix($0) } ||
            UserDefaultsKeys.allKeyPrefixes.contains(key)
        }
        
        // Calculate actual data sizes
        for key in appKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += Int64(data.count)
            } else if let string = userDefaults.string(forKey: key) {
                totalSize += Int64(string.utf8.count)
            } else if userDefaults.object(forKey: key) != nil {
                // Conservative estimate for other types (integers, booleans, etc.)
                totalSize += 50
            }
        }
        
        // Format size
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        
        let sizeString = formatter.string(fromByteCount: totalSize)
        
        // Log detailed breakdown for debugging
        let breakdown = _getDetailedCacheBreakdown()
        logger.log("Data size breakdown - Total: \(sizeString), Play counts: \(breakdown.playCountEntries), Rank history: \(breakdown.rankHistoryEntries), Enhanced songs: \(breakdown.enhancedSongEntries), Artwork: \(breakdown.artworkEntries), MusicKit cache: \(breakdown.musicKitSearchEntries)", level: .debug)
        
        return sizeString
    }
    
    // CRITICAL FIX: Detailed cache breakdown
    func getDetailedCacheBreakdown() -> CacheBreakdown {
        return queue.sync { [weak self] in
            return self?._getDetailedCacheBreakdown() ?? CacheBreakdown(
                totalSize: "0 KB",
                playCountSize: "0 KB", playCountEntries: 0,
                rankHistorySize: "0 KB", rankHistoryEntries: 0,
                enhancedSongSize: "0 KB", enhancedSongEntries: 0,
                artworkSize: "0 KB", artworkEntries: 0,
                musicKitSearchSize: "0 KB", musicKitSearchEntries: 0
            )
        }
    }
    
    private func _getDetailedCacheBreakdown() -> CacheBreakdown {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Count entries and calculate sizes by type
        let playCountKeys = allKeys.filter { $0.hasPrefix("localPlayCount_") || $0.hasPrefix("baselinePlayCount_") }
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        let enhancedSongKeys = allKeys.filter { $0.hasPrefix("enhancedSong_") }
        let artworkKeys = allKeys.filter { $0.hasPrefix("artwork_") }
        let musicKitSearchKeys = allKeys.filter { $0.hasPrefix("musicKitSearch_") }
        
        // Calculate sizes for each category
        let playCountSize = calculateKeysSize(playCountKeys, estimate: 50) // Small integers
        let rankHistorySize = calculateKeysSize(rankHistoryKeys, estimate: 0) // Variable JSON data
        let enhancedSongSize = calculateKeysSize(enhancedSongKeys, estimate: 0) // Variable JSON data
        let artworkSize = calculateKeysSize(artworkKeys, estimate: 0) // Variable binary data
        let musicKitSearchSize = calculateKeysSize(musicKitSearchKeys, estimate: 0) // Variable JSON data
        
        let totalSize = playCountSize + rankHistorySize + enhancedSongSize + artworkSize + musicKitSearchSize
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        
        return CacheBreakdown(
            totalSize: formatter.string(fromByteCount: totalSize),
            playCountSize: formatter.string(fromByteCount: playCountSize), playCountEntries: playCountKeys.count,
            rankHistorySize: formatter.string(fromByteCount: rankHistorySize), rankHistoryEntries: rankHistoryKeys.count,
            enhancedSongSize: formatter.string(fromByteCount: enhancedSongSize), enhancedSongEntries: enhancedSongKeys.count,
            artworkSize: formatter.string(fromByteCount: artworkSize), artworkEntries: artworkKeys.count,
            musicKitSearchSize: formatter.string(fromByteCount: musicKitSearchSize), musicKitSearchEntries: musicKitSearchKeys.count
        )
    }
    
    private func calculateKeysSize(_ keys: [String], estimate: Int) -> Int64 {
        let userDefaults = UserDefaults.standard
        var totalSize: Int64 = 0
        
        for key in keys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += Int64(data.count)
            } else if let string = userDefaults.string(forKey: key) {
                totalSize += Int64(string.utf8.count)
            } else if userDefaults.object(forKey: key) != nil {
                totalSize += Int64(estimate > 0 ? estimate : 100) // Default estimate
            }
        }
        
        return totalSize
    }
    
    // CRITICAL FIX: Cache integrity validation
    func validateCacheIntegrity() -> CacheIntegrityReport {
        return queue.sync { [weak self] in
            return self?._validateCacheIntegrity() ?? CacheIntegrityReport(
                totalEntries: 0, validEntries: 0, staleEntries: 0, corruptedEntries: 0, orphanedKeys: 0,
                enhancedSongIntegrity: (0, 0, 0), artworkIntegrity: (0, 0, 0), searchIntegrity: (0, 0, 0),
                recommendations: ["Validation unavailable"], healthScore: 0.0
            )
        }
    }
    
    private func _validateCacheIntegrity() -> CacheIntegrityReport {
        logger.log("Performing comprehensive cache integrity validation", level: .info)
        
        // Validate enhanced song cache
        let enhancedSongIntegrity = enhancedSongCacheService.getCacheValidationInfo()
        
        // Validate artwork cache
        let artworkIntegrity = artworkPersistenceService.getArtworkCacheValidationInfo()
        
        // Validate search cache
        let searchIntegrity = validateMusicKitSearchCache()
        
        // Find orphaned keys
        let orphanedKeys = findOrphanedKeys()
        
        // Calculate totals
        let totalEntries = enhancedSongIntegrity.valid + enhancedSongIntegrity.stale + enhancedSongIntegrity.corrupted +
                          artworkIntegrity.valid + artworkIntegrity.stale + artworkIntegrity.corrupted +
                          searchIntegrity.valid + searchIntegrity.stale + searchIntegrity.corrupted
        
        let validEntries = enhancedSongIntegrity.valid + artworkIntegrity.valid + searchIntegrity.valid
        let staleEntries = enhancedSongIntegrity.stale + artworkIntegrity.stale + searchIntegrity.stale
        let corruptedEntries = enhancedSongIntegrity.corrupted + artworkIntegrity.corrupted + searchIntegrity.corrupted
        
        // Generate recommendations
        var recommendations: [String] = []
        
        if corruptedEntries > 0 {
            recommendations.append("Remove \(corruptedEntries) corrupted cache entries")
        }
        
        if staleEntries > 0 {
            recommendations.append("Refresh \(staleEntries) stale cache entries")
        }
        
        if orphanedKeys.count > 0 {
            recommendations.append("Clean up \(orphanedKeys.count) orphaned cache keys")
        }
        
        if enhancedSongIntegrity.corrupted > 0 {
            recommendations.append("Enhanced song cache needs repair")
        }
        
        if artworkIntegrity.corrupted > 0 {
            recommendations.append("Artwork cache needs repair")
        }
        
        if searchIntegrity.corrupted > 0 {
            recommendations.append("Search cache needs repair")
        }
        
        if recommendations.isEmpty {
            recommendations.append("All caches are healthy and consistent")
        }
        
        // Calculate health score
        let healthScore = calculateCacheHealthScore(
            total: totalEntries,
            valid: validEntries,
            stale: staleEntries,
            corrupted: corruptedEntries,
            orphaned: orphanedKeys.count
        )
        
        return CacheIntegrityReport(
            totalEntries: totalEntries,
            validEntries: validEntries,
            staleEntries: staleEntries,
            corruptedEntries: corruptedEntries,
            orphanedKeys: orphanedKeys.count,
            enhancedSongIntegrity: enhancedSongIntegrity,
            artworkIntegrity: artworkIntegrity,
            searchIntegrity: searchIntegrity,
            recommendations: recommendations,
            healthScore: healthScore
        )
    }
    
    private func calculateCacheHealthScore(total: Int, valid: Int, stale: Int, corrupted: Int, orphaned: Int) -> Double {
        guard total > 0 else { return 1.0 }
        
        let validRatio = Double(valid) / Double(total)
        let staleRatio = Double(stale) / Double(total)
        let corruptedRatio = Double(corrupted) / Double(total)
        let orphanedRatio = Double(orphaned) / Double(total + orphaned)
        
        var score = validRatio // Start with valid ratio
        score -= staleRatio * 0.3 // Stale entries reduce score by 30%
        score -= corruptedRatio * 0.7 // Corrupted entries reduce score by 70%
        score -= orphanedRatio * 0.5 // Orphaned keys reduce score by 50%
        
        return max(0.0, min(1.0, score))
    }
    
    private func validateMusicKitSearchCache() -> (valid: Int, stale: Int, corrupted: Int) {
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
            let maxAge: TimeInterval = 14 * 24 * 60 * 60
            if Date().timeIntervalSince(cachedResult.timestamp) > maxAge {
                stale += 1
            } else if cachedResult.version != CachedMusicKitResult.currentVersion {
                stale += 1
            } else {
                valid += 1
            }
        }
        
        return (valid: valid, stale: stale, corrupted: corrupted)
    }
    
    private func findOrphanedKeys() -> [String] {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        var orphanedKeys: [String] = []
        
        for key in allKeys {
            // Check if this is an app-related key
            let isAppKey = UserDefaultsKeys.allKeyPrefixes.contains { key.hasPrefix($0) } ||
                          UserDefaultsKeys.allKeyPrefixes.contains(key)
            
            if isAppKey && !isValidCacheKey(key) {
                orphanedKeys.append(key)
            }
        }
        
        return orphanedKeys
    }
    
    private func isValidCacheKey(_ key: String) -> Bool {
        let userDefaults = UserDefaults.standard
        
        // Metadata keys are always valid
        let metadataKeys = [
            UserDefaultsKeys.enhancedSongMetadata,
            UserDefaultsKeys.musicKitSearchMetadata,
            UserDefaultsKeys.artworkMetadata,
            UserDefaultsKeys.savedArtworkSongId,
            UserDefaultsKeys.savedArtworkTimestamp,
            UserDefaultsKeys.cacheLastCleanupDate
        ]
        
        if metadataKeys.contains(key) {
            return true
        }
        
        // Check if the key has valid data
        if key.hasPrefix("enhancedSong_") {
            guard let data = userDefaults.data(forKey: key),
                  let _ = try? JSONDecoder().decode(CachedSongEnhancement.self, from: data) else {
                return false
            }
            return true
        }
        
        if key.hasPrefix("musicKitSearch_") {
            guard let data = userDefaults.data(forKey: key),
                  let _ = try? JSONDecoder().decode(CachedMusicKitResult.self, from: data) else {
                return false
            }
            return true
        }
        
        if key.hasPrefix("artwork_") {
            guard let data = userDefaults.data(forKey: key),
                  !data.isEmpty,
                  UIImage(data: data) != nil else {
                return false
            }
            return true
        }
        
        if key.hasPrefix("rankSnapshots_") {
            guard let data = userDefaults.data(forKey: key),
                  let _ = try? JSONDecoder().decode([RankSnapshot].self, from: data) else {
                return false
            }
            return true
        }
        
        if key.hasPrefix("localPlayCount_") || key.hasPrefix("baselinePlayCount_") {
            // These should be integers
            return userDefaults.object(forKey: key) is Int
        }
        
        return false
    }
    
    // MARK: - Private Clearing Methods
    
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
        
        logger.log("Cleared remaining app metadata entries", level: .info)
    }
    
    // CRITICAL FIX: Thorough key cleanup
    private func performThoroughKeyCleanup() {
        let orphanedKeys = findOrphanedKeys()
        
        if !orphanedKeys.isEmpty {
            let userDefaults = UserDefaults.standard
            
            for key in orphanedKeys {
                userDefaults.removeObject(forKey: key)
            }
            
            logger.log("Cleaned up \(orphanedKeys.count) orphaned cache keys", level: .info)
        }
    }
    
    // MARK: - Helper Methods for Individual Cache Sizes (Kept for compatibility)
    
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
