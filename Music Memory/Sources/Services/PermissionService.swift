import Foundation
import MediaPlayer
import MusicKit

protocol PermissionServiceProtocol {
    func requestMusicLibraryPermission() async -> Bool
    func checkMusicLibraryPermissionStatus() async -> AppPermissionStatus
    func requestMusicKitPermission() async -> Bool
    func checkMusicKitPermissionStatus() async -> AppPermissionStatus
    func checkBothPermissionStatuses() async -> (mediaPlayer: AppPermissionStatus, musicKit: AppPermissionStatus)
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
    
    func requestMusicKitPermission() async -> Bool {
        do {
            let status = await MusicAuthorization.request()
            return status == .authorized
        } catch {
            print("Failed to request MusicKit permission: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkMusicKitPermissionStatus() async -> AppPermissionStatus {
        let status = await MusicAuthorization.currentStatus
        
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
    
    func checkBothPermissionStatuses() async -> (mediaPlayer: AppPermissionStatus, musicKit: AppPermissionStatus) {
        let mediaPlayerStatus = await checkMusicLibraryPermissionStatus()
        let musicKitStatus = await checkMusicKitPermissionStatus()
        
        return (mediaPlayer: mediaPlayerStatus, musicKit: musicKitStatus)
    }
}
