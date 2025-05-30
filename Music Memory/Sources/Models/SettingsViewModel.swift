import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var showingClearDataAlert = false
    @Published var isClearing = false
    @Published var localDataSize = "Calculating..."
    
    private let settingsService: SettingsServiceProtocol
    private let logger: LoggerProtocol
    
    init(settingsService: SettingsServiceProtocol, logger: LoggerProtocol) {
        self.settingsService = settingsService
        self.logger = logger
        
        // Calculate initial data size
        calculateDataSize()
    }
    
    func calculateDataSize() {
        Task {
            let size = await Task.detached { [settingsService] in
                return settingsService.getLocalTrackingDataSize()
            }.value
            
            await MainActor.run {
                self.localDataSize = size
            }
        }
    }
    
    func showClearDataConfirmation() {
        AppHaptics.warning()
        showingClearDataAlert = true
    }
    
    func clearAllLocalData() async {
        isClearing = true
        
        // Provide heavy impact haptic for this significant action
        AppHaptics.heavyImpact()
        
        logger.log("User initiated clear all local tracking data", level: .info)
        
        // Perform the clearing operation on a background task
        await Task.detached { [settingsService] in
            settingsService.clearAllLocalTrackingData()
        }.value
        
        // Update data size after clearing
        calculateDataSize()
        
        isClearing = false
        
        // Provide success haptic feedback
        AppHaptics.success()
        
        logger.log("Successfully cleared all local tracking data", level: .info)
        
        // Post notification to refresh the song list if needed
        NotificationCenter.default.post(name: .localDataCleared, object: nil)
    }
    
    // MARK: - Additional Cache Info Methods (for detailed view if needed)
    
    func getDetailedCacheInfo() -> CacheInfo {
        // Get individual cache sizes for detailed breakdown
        let playCountSize = (settingsService as? SettingsService)?.getPlayCountCacheSize() ?? "Unknown"
        let rankHistorySize = (settingsService as? SettingsService)?.getRankHistoryCacheSize() ?? "Unknown"
        let enhancedSongSize = (settingsService as? SettingsService)?.getEnhancedSongCacheSize() ?? "Unknown"
        let artworkSize = (settingsService as? SettingsService)?.getArtworkCacheSize() ?? "Unknown"
        let musicKitSearchSize = (settingsService as? SettingsService)?.getMusicKitSearchCacheSize() ?? "Unknown"
        
        return CacheInfo(
            totalSize: localDataSize,
            playCountSize: playCountSize,
            rankHistorySize: rankHistorySize,
            enhancedSongSize: enhancedSongSize,
            artworkSize: artworkSize,
            musicKitSearchSize: musicKitSearchSize
        )
    }
}

// MARK: - Cache Info Structure

struct CacheInfo {
    let totalSize: String
    let playCountSize: String
    let rankHistorySize: String
    let enhancedSongSize: String
    let artworkSize: String
    let musicKitSearchSize: String
    
    var breakdown: [(name: String, size: String)] {
        return [
            ("Play Count Tracking", playCountSize),
            ("Rank History", rankHistorySize),
            ("Enhanced Song Data", enhancedSongSize),
            ("Artwork Cache", artworkSize),
            ("MusicKit Search Cache", musicKitSearchSize)
        ]
    }
}

// Add notification for data clearing
extension NSNotification.Name {
    static let localDataCleared = NSNotification.Name("localDataCleared")
}
