import Foundation
import Combine
import SwiftUI

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var permissionStatus: AppPermissionStatus = .unknown
    
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let logger: LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.logger = logger
    }
    
    @MainActor
    func loadSongs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            permissionStatus = await musicLibraryService.checkPermissionStatus()
            
            if permissionStatus == .granted {
                songs = try await musicLibraryService.fetchSongs()
            } else if permissionStatus == .notRequested || permissionStatus == .unknown {
                let granted = await requestPermission()
                if granted {
                    songs = try await musicLibraryService.fetchSongs()
                }
            }
        } catch {
            logger.log("Error loading songs: \(error.localizedDescription)", level: .error)
            if let appError = error as? AppError {
                handleError(appError)
            } else {
                handleError(AppError.unknown(error))
            }
        }
    }
    
    @MainActor
    func requestPermission() async -> Bool {
        let granted = await musicLibraryService.requestPermission()
        permissionStatus = granted ? .granted : .denied
        return granted
    }
    
    private func handleError(_ error: AppError) {
        NotificationCenter.default.post(
            name: .appErrorOccurred,
            object: error
        )
    }
}
