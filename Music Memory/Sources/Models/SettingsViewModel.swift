import Foundation
import SwiftUI

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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let size = self.settingsService.getLocalTrackingDataSize()
            
            DispatchQueue.main.async {
                self.localDataSize = size
            }
        }
    }
    
    func showClearDataConfirmation() {
        AppHaptics.warning()
        showingClearDataAlert = true
    }
    
    @MainActor
    func clearAllLocalData() async {
        isClearing = true
        
        // Provide heavy impact haptic for this significant action
        AppHaptics.heavyImpact()
        
        logger.log("User initiated clear all local tracking data", level: .info)
        
        // Perform the clearing operation on a background queue
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.settingsService.clearAllLocalTrackingData()
                
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
        
        // Update data size after clearing
        calculateDataSize()
        
        isClearing = false
        
        // Provide success haptic feedback
        AppHaptics.success()
        
        logger.log("Successfully cleared all local tracking data", level: .info)
        
        // Post notification to refresh the song list if needed
        NotificationCenter.default.post(name: .localDataCleared, object: nil)
    }
}

// Add notification for data clearing
extension NSNotification.Name {
    static let localDataCleared = NSNotification.Name("localDataCleared")
}
