import SwiftUI
import MediaPlayer
import Combine

// MARK: - Preview Service Implementations

class PreviewPermissionService: PermissionServiceProtocol {
    private let status: AppPermissionStatus
    
    init(status: AppPermissionStatus = .granted) {
        self.status = status
    }
    
    func requestMusicLibraryPermission() async -> Bool {
        return status == .granted
    }
    
    func checkMusicLibraryPermissionStatus() async -> AppPermissionStatus {
        return status
    }
}

class PreviewMusicLibraryService: MusicLibraryServiceProtocol {
    private let mockSongs: [Song]
    private let permissionStatus: AppPermissionStatus
    
    init(mockSongs: [Song] = [], permissionStatus: AppPermissionStatus = .granted) {
        self.mockSongs = mockSongs
        self.permissionStatus = permissionStatus
    }
    
    func requestPermission() async -> Bool {
        return permissionStatus == .granted
    }
    
    func fetchSongs() async throws -> [Song] {
        return mockSongs
    }
    
    func checkPermissionStatus() async -> AppPermissionStatus {
        return permissionStatus
    }
}

// MARK: - Mock MPMediaItem for Previews

class MockMPMediaItem: MPMediaItem {
    var mockTitle: String = ""
    var mockArtist: String = ""
    var mockAlbumTitle: String = ""
    var mockPlayCount: Int = 0
    var mockPersistentID: MPMediaEntityPersistentID = 0
    
    override func value(forProperty property: String) -> Any? {
        switch property {
        case MPMediaItemPropertyTitle:
            return mockTitle
        case MPMediaItemPropertyArtist:
            return mockArtist
        case MPMediaItemPropertyAlbumTitle:
            return mockAlbumTitle
        case MPMediaItemPropertyPlayCount:
            return mockPlayCount
        case MPMediaItemPropertyPersistentID:
            return mockPersistentID
        default:
            return nil
        }
    }
}

// MARK: - Preview Extensions

extension View {
    func previewWithContainer(_ container: DIContainer) -> some View {
        self
            .environmentObject(container)
            .environmentObject(container.appState as! AppState)
    }
}

extension SongDetailViewModel {
    static func preview(song: Song) -> SongDetailViewModel {
        return SongDetailViewModel(
            song: song,
            logger: DIContainer.preview().logger
        )
    }
}
