import Foundation

protocol SettingsServiceProtocol {
    func clearAllLocalTrackingData()
    func getLocalTrackingDataSize() -> String
}

class SettingsService: SettingsServiceProtocol {
    private let logger: LoggerProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    
    init(
        logger: LoggerProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol,
        rankHistoryService: RankHistoryServiceProtocol
    ) {
        self.logger = logger
        self.artworkPersistenceService = artworkPersistenceService
        self.rankHistoryService = rankHistoryService
    }
    
    func clearAllLocalTrackingData() {
        logger.log("Starting to clear all local tracking data", level: .info)
        
        // Clear all local play counts
        clearLocalPlayCounts()
        
        // Clear all rank history snapshots
        clearRankHistoryData()
        
        // Clear saved artwork
        artworkPersistenceService.clearSavedArtwork()
        artworkPersistenceService.cleanupOldArtwork()
        
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
        
        // Estimate UserDefaults size (rough calculation)
        let userDefaultsSize = (playCountKeys.count + rankHistoryKeys.count) * 100 // Rough estimate
        totalSize += Int64(userDefaultsSize)
        
        // Calculate artwork files size
        if let documentsPath = getDocumentsDirectory() {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey])
                let artworkFiles = files.filter { $0.lastPathComponent.hasPrefix("saved_artwork_") }
                
                for file in artworkFiles {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                       let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                }
            } catch {
                logger.log("Failed to calculate artwork files size: \(error.localizedDescription)", level: .warning)
            }
        }
        
        // Format size
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
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
    
    private func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
