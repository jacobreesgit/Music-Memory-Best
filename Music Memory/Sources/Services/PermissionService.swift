import Foundation
import MediaPlayer

protocol PermissionServiceProtocol {
    func requestMusicLibraryPermission() async -> Bool
    func checkMusicLibraryPermissionStatus() async -> AppPermissionStatus
}

class PermissionService: PermissionServiceProtocol {
    func requestMusicLibraryPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func checkMusicLibraryPermissionStatus() async -> AppPermissionStatus {
        let status = MPMediaLibrary.authorizationStatus()
        
        switch status {
        case .notDetermined:
            return .notRequested
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .unknown
        }
    }
}
