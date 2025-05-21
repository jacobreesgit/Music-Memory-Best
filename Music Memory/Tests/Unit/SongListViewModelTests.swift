import XCTest
import MediaPlayer
import Combine
@testable import MusicMemory

class SongListViewModelTests: XCTestCase {
    var mockMusicLibraryService: MockMusicLibraryService!
    var mockLogger: MockLogger!
    var sut: SongListViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockMusicLibraryService = MockMusicLibraryService()
        mockLogger = MockLogger()
        sut = SongListViewModel(
            musicLibraryService: mockMusicLibraryService,
            logger: mockLogger
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        mockMusicLibraryService = nil
        mockLogger = nil
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testLoadSongsWhenPermissionGranted() async {
        // Given
        let expectedSongs = createMockSongs(count: 3)
        mockMusicLibraryService.mockPermissionStatus = .granted
        mockMusicLibraryService.mockSongs = expectedSongs
        
        // When
        await sut.loadSongs()
        
        // Then
        XCTAssertEqual(sut.songs.count, expectedSongs.count)
        XCTAssertEqual(sut.permissionStatus, .granted)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(mockMusicLibraryService.fetchSongsCallCount, 1)
    }
    
    func testLoadSongsRequestsPermissionWhenNotRequested() async {
        // Given
        let expectedSongs = createMockSongs(count: 2)
        mockMusicLibraryService.mockPermissionStatus = .notRequested
        mockMusicLibraryService.mockPermissionResult = true
        mockMusicLibraryService.mockSongs = expectedSongs
        
        // When
        await sut.loadSongs()
        
        // Then
        XCTAssertEqual(sut.songs.count, expectedSongs.count)
        XCTAssertEqual(sut.permissionStatus, .granted)
        XCTAssertEqual(mockMusicLibraryService.requestPermissionCallCount, 1)
        XCTAssertEqual(mockMusicLibraryService.fetchSongsCallCount, 1)
    }
    
    func testLoadSongsHandlesPermissionDenied() async {
        // Given
        mockMusicLibraryService.mockPermissionStatus = .notRequested
        mockMusicLibraryService.mockPermissionResult = false
        
        // When
        await sut.loadSongs()
        
        // Then
        XCTAssertTrue(sut.songs.isEmpty)
        XCTAssertEqual(sut.permissionStatus, .denied)
        XCTAssertEqual(mockMusicLibraryService.requestPermissionCallCount, 1)
        XCTAssertEqual(mockMusicLibraryService.fetchSongsCallCount, 0)
    }
    
    func testLoadSongsHandlesError() async {
        // Given
        mockMusicLibraryService.mockPermissionStatus = .granted
        mockMusicLibraryService.mockError = AppError.noMediaItemsFound
        
        // Expect error notification
        let expectation = self.expectation(description: "Error notification posted")
        NotificationCenter.default.addObserver(forName: .appErrorOccurred, object: nil, queue: .main) { notification in
            if let error = notification.object as? AppError,
               case .noMediaItemsFound = error {
                expectation.fulfill()
            }
        }
        
        // When
        await sut.loadSongs()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(sut.songs.isEmpty)
        XCTAssertEqual(sut.permissionStatus, .granted)
        XCTAssertEqual(mockMusicLibraryService.fetchSongsCallCount, 1)
    }
    
    // Helper method to create mock songs
    private func createMockSongs(count: Int) -> [Song] {
        var songs: [Song] = []
        
        for i in 0..<count {
            let song = Song(
                id: "song_\(i)",
                title: "Song \(i)",
                artist: "Artist \(i)",
                album: "Album \(i)",
                playCount: i * 5,
                artwork: nil,
                mediaItem: MPMediaItem()
            )
            songs.append(song)
        }
        
        return songs
    }
}

// Mock class for MusicLibraryService
class MockMusicLibraryService: MusicLibraryServiceProtocol {
    var mockPermissionStatus: AppPermissionStatus = .unknown
    var mockPermissionResult = false
    var mockSongs: [Song] = []
    var mockError: Error?
    
    var requestPermissionCallCount = 0
    var checkPermissionStatusCallCount = 0
    var fetchSongsCallCount = 0
    
    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
        return mockPermissionResult
    }
    
    func checkPermissionStatus() async -> AppPermissionStatus {
        checkPermissionStatusCallCount += 1
        return mockPermissionStatus
    }
    
    func fetchSongs() async throws -> [Song] {
        fetchSongsCallCount += 1
        
        if let error = mockError {
            throw error
        }
        
        return mockSongs
    }
}
