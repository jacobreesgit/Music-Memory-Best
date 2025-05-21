import Foundation
import Combine
import SwiftUI
import UIKit

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var permissionStatus: AppPermissionStatus = .unknown
    
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let logger: LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    let errorSubject = PassthroughSubject<AppError, Never>()
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.logger = logger
        setupErrorHandling()
    }
    
    private func setupErrorHandling() {
        errorSubject
            .receive(on: RunLoop.main)
            .sink { error in
                NotificationCenter.default.post(
                    name: .appErrorOccurred,
                    object: error
                )
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func loadSongs() async {
        isLoading = true
        defer { isLoading = false }
        
        logger.log("Pull to refresh initiated", level: .info)
        
        do {
            // Check current permission status first
            await updatePermissionStatus(musicLibraryService.checkPermissionStatus())
            
            // If permission is already granted, invalidate the cache and load songs
            if permissionStatus == .granted {
                await musicLibraryService.invalidateCache()
                songs = try await musicLibraryService.fetchSongs()
                logger.log("Pull to refresh completed successfully, fetched \(songs.count) songs", level: .info)
            }
            // Otherwise, just wait for user to tap "Allow Access"
        } catch {
            logger.log("Error loading songs: \(error.localizedDescription)", level: .error)
            handleError(error)
        }
    }
    
    @MainActor
    func requestPermission() async -> Bool {
        // Set the state to "requested" to show appropriate UI
        await updatePermissionStatus(.requested)
        
        // Request the actual permission
        let granted = await musicLibraryService.requestPermission()
        
        // Update status based on result
        await updatePermissionStatus(granted ? .granted : .denied)
        
        // If permission was granted, load the songs
        if granted {
            do {
                songs = try await musicLibraryService.fetchSongs()
            } catch {
                handleError(error)
            }
        }
        
        return granted
    }
    
    @MainActor
    func updatePermissionStatus(_ status: AppPermissionStatus) async {
        permissionStatus = status
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let appState = appDelegate.appState {
            appState.musicLibraryPermissionStatus = status
        }
    }
    
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            errorSubject.send(appError)
        } else {
            errorSubject.send(AppError.unknown(error))
        }
    }
}

// MARK: - Preview Factory
extension SongListViewModel {
    static func preview(withSongs songs: [Song]) -> SongListViewModel {
        let logger = Logger()
        let mockService = PreviewMusicLibraryService(mockSongs: songs)
        
        let viewModel = SongListViewModel(
            musicLibraryService: mockService,
            logger: logger
        )
        
        // Immediately populate the view model for previews
        viewModel.songs = songs
        viewModel.permissionStatus = .granted
        viewModel.isLoading = false
        
        return viewModel
    }
}
