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
        // Immediately returns the mock songs without simulating any async behavior
        return mockSongs
    }
    
    func checkPermissionStatus() async -> AppPermissionStatus {
        return permissionStatus
    }
    
    func invalidateCache() async {
        // No-op in preview service since we don't cache anything
        // We could post the notification though for completeness
        Task { @MainActor in
            NotificationCenter.default.post(name: .mediaLibraryChanged, object: nil)
        }
    }
    
    func refreshSong(withId id: String) async -> Song? {
        // Find and return the song with the given ID
        return mockSongs.first(where: { $0.id == id })
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

// MARK: - Preview Environment Helpers

struct IsPreviewEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

extension EnvironmentValues {
    var isPreview: Bool {
        get { self[IsPreviewEnvironmentKey.self] }
        set { self[IsPreviewEnvironmentKey.self] = newValue }
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

// MARK: - Mock Song Factory

struct PreviewSongFactory {
    static let mockSongs = [
        createMockSong(id: "1", title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", playCount: 42),
        createMockSong(id: "2", title: "Hotel California", artist: "Eagles", album: "Hotel California", playCount: 35),
        createMockSong(id: "3", title: "Hey Jude", artist: "The Beatles", album: "The Beatles (White Album)", playCount: 28)
    ]
    
    static func createMockSong(id: String, title: String, artist: String, album: String, playCount: Int) -> Song {
        let item = MockMPMediaItem()
        item.mockTitle = title
        item.mockArtist = artist
        item.mockAlbumTitle = album
        item.mockPlayCount = playCount
        
        // Use a positive value for persistent ID
        let persistentID = UInt64(abs(id.hashValue))
        item.mockPersistentID = persistentID
        
        return Song(from: item)
    }
}

// MARK: - ViewModel Preview Factories

extension SongDetailViewModel {
    static func preview(song: Song) -> SongDetailViewModel {
        return SongDetailViewModel(
            song: song,
            logger: DIContainer.preview().logger
        )
    }
}
