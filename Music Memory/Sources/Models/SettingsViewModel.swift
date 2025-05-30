import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var showingClearDataAlert = false
    @Published var isClearing = false
    @Published var localDataSize = "Calculating..."
    @Published var cacheIntegrityReport: CacheIntegrityReport?
    @Published var isValidatingCache = false
    
    private let settingsService: SettingsServiceProtocol
    private let logger: LoggerProtocol
    
    init(settingsService: SettingsServiceProtocol, logger: LoggerProtocol) {
        self.settingsService = settingsService
        self.logger = logger
        
        // Calculate initial data size and validate cache
        calculateDataSize()
        validateCacheIntegrity()
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
    
    // CRITICAL FIX: Cache integrity validation
    func validateCacheIntegrity() {
        isValidatingCache = true
        
        Task {
            let report = await Task.detached { [settingsService] in
                return settingsService.validateCacheIntegrity()
            }.value
            
            await MainActor.run {
                self.cacheIntegrityReport = report
                self.isValidatingCache = false
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
        
        // CRITICAL FIX: Re-validate cache after clearing
        validateCacheIntegrity()
        
        isClearing = false
        
        // Provide success haptic feedback
        AppHaptics.success()
        
        logger.log("Successfully cleared all local tracking data", level: .info)
        
        // Post notification to refresh the song list if needed
        NotificationCenter.default.post(name: .localDataCleared, object: nil)
    }
    
    // MARK: - Cache Management Methods
    
    func getDetailedCacheInfo() -> CacheBreakdown {
        // Get detailed cache breakdown from service
        return settingsService.getDetailedCacheBreakdown()
    }
    
    func getCacheIntegrityReport() -> CacheIntegrityReport? {
        return cacheIntegrityReport
    }
    
    func refreshCacheValidation() {
        validateCacheIntegrity()
    }
    
    // MARK: - Legacy Cache Info Methods (Updated to use new system)
    
    func getPlayCountCacheSize() -> String {
        return (settingsService as? SettingsService)?.getPlayCountCacheSize() ?? "Unknown"
    }
    
    func getRankHistoryCacheSize() -> String {
        return (settingsService as? SettingsService)?.getRankHistoryCacheSize() ?? "Unknown"
    }
    
    func getEnhancedSongCacheSize() -> String {
        return (settingsService as? SettingsService)?.getEnhancedSongCacheSize() ?? "Unknown"
    }
    
    func getArtworkCacheSize() -> String {
        return (settingsService as? SettingsService)?.getArtworkCacheSize() ?? "Unknown"
    }
    
    func getMusicKitSearchCacheSize() -> String {
        return (settingsService as? SettingsService)?.getMusicKitSearchCacheSize() ?? "Unknown"
    }
    
    // MARK: - Cache Health Summary
    
    var cacheHealthSummary: String {
        guard let report = cacheIntegrityReport else {
            return "Validating..."
        }
        
        return report.problemSummary
    }
    
    var cacheHealthColor: Color {
        guard let report = cacheIntegrityReport else {
            return AppColors.secondary
        }
        
        if report.healthScore >= 0.8 {
            return AppColors.success
        } else if report.healthScore >= 0.5 {
            return AppColors.warning
        } else {
            return AppColors.destructive
        }
    }
    
    var shouldShowCacheWarning: Bool {
        guard let report = cacheIntegrityReport else { return false }
        return report.hasProblems
    }
}

// MARK: - Cache Info Structure (Updated for compatibility)

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
    
    // CRITICAL FIX: Create from CacheBreakdown
    init(from breakdown: CacheBreakdown) {
        self.totalSize = breakdown.totalSize
        self.playCountSize = breakdown.playCountSize
        self.rankHistorySize = breakdown.rankHistorySize
        self.enhancedSongSize = breakdown.enhancedSongSize
        self.artworkSize = breakdown.artworkSize
        self.musicKitSearchSize = breakdown.musicKitSearchSize
    }
    
    // Legacy initializer for backward compatibility
    init(
        totalSize: String,
        playCountSize: String,
        rankHistorySize: String,
        enhancedSongSize: String,
        artworkSize: String,
        musicKitSearchSize: String
    ) {
        self.totalSize = totalSize
        self.playCountSize = playCountSize
        self.rankHistorySize = rankHistorySize
        self.enhancedSongSize = enhancedSongSize
        self.artworkSize = artworkSize
        self.musicKitSearchSize = musicKitSearchSize
    }
}

// Extension to bridge the old API to the new system
extension SettingsViewModel {
    func getDetailedCacheInfoLegacy() -> CacheInfo {
        let breakdown = getDetailedCacheInfo()
        return CacheInfo(from: breakdown)
    }
}

// Add notification for data clearing (if not already present)
extension NSNotification.Name {
    static let localDataCleared = NSNotification.Name("localDataCleared")
}
