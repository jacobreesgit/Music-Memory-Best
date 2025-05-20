//import XCTest
//import MediaPlayer
//@testable import MusicMemory
//
//class MusicLibraryServiceTests: XCTestCase {
//    var mockPermissionService: MockPermissionService!
//    var mockLogger: MockLogger!
//    var sut: MusicLibraryService!
//    
//    override func setUp() {
//        super.setUp()
//        mockPermissionService = MockPermissionService()
//        mockLogger = MockLogger()
//        sut = MusicLibraryService(
//            permissionService: mockPermissionService,
//            logger: mockLogger
//        )
//    }
//    
//    override func tearDown() {
//        mockPermissionService = nil
//        mockLogger = nil
//        sut = nil
//        super.tearDown()
//    }
//    
//    func testCheckPermissionStatus() async {
//        // Given
//        mockPermissionService.mockPermissionStatus = .granted
//        
//        // When
//        let status = await sut.checkPermissionStatus()
//        
//        // Then
//        XCTAssertEqual(status, .granted)
//        XCTAssertEqual(mockPermissionService.checkPermissionStatusCallCount, 1)
//    }
//    
//    func testRequestPermission() async {
//        // Given
//        mockPermissionService.mockPermissionResult = true
//        
//        // When
//        let result = await sut.requestPermission()
//        
//        // Then
//        XCTAssertTrue(result)
//        XCTAssertEqual(mockPermissionService.requestPermissionCallCount, 1)
//    }
//    
//    func testFetchSongsThrowsErrorWhenPermissionDenied() async {
//        // Given
//        mockPermissionService.mockPermissionStatus = .denied
//        
//        // When/Then
//        do {
//            _ = try await sut.fetchSongs()
//            XCTFail("Expected error to be thrown")
//        } catch {
//            XCTAssertTrue(error is AppError)
//            if let appError = error as? AppError {
//                XCTAssertEqual(appError, AppError.permissionDenied)
//            }
//        }
//    }
//}
//
//// Mock classes for testing
//class MockPermissionService: PermissionServiceProtocol {
//    var mockPermissionResult = false
//    var mockPermissionStatus: AppPermissionStatus = .unknown
//    var requestPermissionCallCount = 0
//    var checkPermissionStatusCallCount = 0
//    
//    func requestMusicLibraryPermission() async -> Bool {
//        requestPermissionCallCount += 1
//        return mockPermissionResult
//    }
//    
//    func checkMusicLibraryPermissionStatus() async -> AppPermissionStatus {
//        checkPermissionStatusCallCount += 1
//        return mockPermissionStatus
//    }
//}
//
//class MockLogger: LoggerProtocol {
//    var logs: [(message: String, level: LogLevel)] = []
//    
//    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
//        logs.append((message: message, level: level))
//    }
//}
