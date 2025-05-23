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
        setupNotificationHandlers()
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
    
    private func setupNotificationHandlers() {
        // Listen for single song refresh requests
        NotificationCenter.default.publisher(for: .refreshSingleSong)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let songId = notification.object as? String {
                    Task {
                        await self?.refreshSingleSong(withId: songId)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for full library refresh (like from pull-to-refresh)
        NotificationCenter.default.publisher(for: .mediaLibraryChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAllSongs()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func loadSongs() async {
        isLoading = true
        defer { isLoading = false }
        
        logger.log("Loading songs", level: .info)
        
        do {
            // Check current permission status first
            await updatePermissionStatus(musicLibraryService.checkPermissionStatus())
            
            // If permission is granted, load songs
            if permissionStatus == .granted {
                await refreshAllSongs()
            }
        } catch {
            logger.log("Error loading songs: \(error.localizedDescription)", level: .error)
            handleError(error)
        }
    }
    
    @MainActor
    func refreshAllSongs() async {
        logger.log("Refreshing all songs", level: .info)
        
        do {
            // Always invalidate cache first to ensure fresh data
            await musicLibraryService.invalidateCache()
            
            // Fetch fresh songs
            let freshSongs = try await musicLibraryService.fetchSongs()
            
            // Update the songs array on main thread
            self.songs = freshSongs
            
            logger.log("Refreshed all songs successfully, count: \(freshSongs.count)", level: .info)
            
            // Post notification that songs have been updated
            NotificationCenter.default.post(name: .songsListUpdated, object: freshSongs)
        } catch {
            logger.log("Error refreshing songs: \(error.localizedDescription)", level: .error)
            handleError(error)
        }
    }
    
    @MainActor
    func refreshSingleSong(withId songId: String) async {
        logger.log("Refreshing single song with ID: \(songId)", level: .info)
        
        // Find the song in our current list
        guard let currentIndex = songs.firstIndex(where: { $0.id == songId }) else {
            logger.log("Song not found in current list: \(songId)", level: .warning)
            return
        }
        
        // Fetch the updated song data
        guard let updatedSong = await musicLibraryService.refreshSong(withId: songId) else {
            logger.log("Failed to refresh song: \(songId)", level: .error)
            return
        }
        
        // Update the song in our list
        songs[currentIndex] = updatedSong
        
        // Re-sort the list if play count changed
        let oldPlayCount = songs[currentIndex].playCount
        if updatedSong.playCount != oldPlayCount {
            logger.log("Play count changed from \(oldPlayCount) to \(updatedSong.playCount), re-sorting", level: .info)
            songs.sort(by: { $0.playCount > $1.playCount })
        }
        
        // Post notification that songs have been updated
        NotificationCenter.default.post(name: .songsListUpdated, object: songs)
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
            await loadSongs()
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

// MARK: - Notification Names
extension NSNotification.Name {
    static let refreshSingleSong = NSNotification.Name("refreshSingleSong")
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
