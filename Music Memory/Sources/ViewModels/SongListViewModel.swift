import Foundation
import Combine
import SwiftUI
import UIKit

enum SortOption: String, CaseIterable {
    case playCount = "Play Count"
    case title = "Title"
    
    var systemImage: String {
        switch self {
        case .playCount:
            return "number"
        case .title:
            return "textformat.abc"
        }
    }
    
    var defaultDirection: SortDirection {
        switch self {
        case .playCount:
            return .descending // Highest play count first
        case .title:
            return .ascending // Alphabetical A-Z order
        }
    }
}

enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
    
    var systemImage: String {
        switch self {
        case .ascending:
            return "chevron.up"
        case .descending:
            return "chevron.down"
        }
    }
}

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var permissionStatus: AppPermissionStatus = .unknown
    @Published var sortDescriptor = SortDescriptor(option: .playCount, direction: .descending)
    @Published var rankChanges: [String: RankChange] = [:]
    
    private var allSongs: [Song] = [] // Store original unsorted songs
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let logger: LoggerProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isAppLaunching = true
    let errorSubject = PassthroughSubject<AppError, Never>()
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        logger: LoggerProtocol,
        rankHistoryService: RankHistoryServiceProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.logger = logger
        self.rankHistoryService = rankHistoryService
        setupErrorHandling()
        setupPlayCompletionListener()
        setupLocalDataClearedListener()
        
        // Cleanup old snapshots on initialization (once per app launch)
        Task {
            await MainActor.run {
                rankHistoryService.cleanupOldSnapshots()
            }
        }
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
    
    private func setupPlayCompletionListener() {
        // Listen for song play completion notifications
        NotificationCenter.default.publisher(for: .songPlayCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let songId = notification.userInfo?[Notification.SongKeys.completedSongId] as? String else { return }
                
                self.handleSongPlayCompleted(songId: songId)
            }
            .store(in: &cancellables)
    }
    
    private func setupLocalDataClearedListener() {
        // Listen for local data cleared notifications
        NotificationCenter.default.publisher(for: .localDataCleared)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleLocalDataCleared()
            }
            .store(in: &cancellables)
    }
    
    private func handleLocalDataCleared() {
        logger.log("Local data cleared - refreshing song list", level: .info)
        
        // Clear rank changes since rank history was cleared
        rankChanges.removeAll()
        
        // Refresh the song list to reflect cleared local play counts
        applySorting()
        
        // Post notification to update Now Playing bar
        NotificationCenter.default.post(
            name: .songsListUpdated,
            object: nil,
            userInfo: [Notification.SongKeys.updatedSongs: songs]
        )
    }
    
    private func handleSongPlayCompleted(songId: String) {
        logger.log("Handling play completion for song ID: \(songId)", level: .info)
        
        // Find the song in our list
        guard let songIndex = allSongs.firstIndex(where: { $0.id == songId }) else {
            logger.log("Song with ID \(songId) not found in list", level: .warning)
            return
        }
        
        let song = allSongs[songIndex]
        let previousRank = songs.firstIndex(where: { $0.id == songId }).map { $0 + 1 }
        
        // Re-sort if we're sorting by play count
        if sortDescriptor.option == .playCount {
            logger.log("Re-sorting list after play count increment for '\(song.title)'", level: .info)
            
            // 1. Save current state before re-sorting
            rankHistoryService.saveRankSnapshot(songs: songs, sortDescriptor: sortDescriptor)
            
            // 2. Apply sorting with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                applySorting()
            }
            
            // 3. Compute rank changes
            rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
            
            // 4. Post notification that songs list was updated
            NotificationCenter.default.post(
                name: .songsListUpdated,
                object: nil,
                userInfo: [Notification.SongKeys.updatedSongs: songs]
            )
            
            // Log position change if any
            if let newIndex = songs.firstIndex(where: { $0.id == songId }) {
                let newRank = newIndex + 1
                if let oldRank = previousRank, oldRank != newRank {
                    logger.log("Song '\(song.title)' moved from rank #\(oldRank) to #\(newRank)", level: .info)
                }
            }
        }
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
                let fetchedSongs = try await musicLibraryService.fetchSongs()
                
                // Sync play counts only on fresh app launch
                if isAppLaunching {
                    logger.log("App launching - syncing play counts", level: .info)
                    for song in fetchedSongs {
                        song.syncPlayCounts(logger: logger)
                    }
                    isAppLaunching = false
                }
                
                self.allSongs = fetchedSongs
                applySorting()
                
                // Compute initial rank changes when loading songs
                if sortDescriptor.option == .playCount {
                    rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
                }
                
                logger.log("Loaded \(fetchedSongs.count) songs successfully", level: .info)
                
                // Initial notification to update Now Playing bar rank
                NotificationCenter.default.post(
                    name: .songsListUpdated,
                    object: nil,
                    userInfo: [Notification.SongKeys.updatedSongs: songs]
                )
            }
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
    
    func updateSortDescriptor(option: SortOption) {
        let newDirection = (sortDescriptor.option == option)
            ? (sortDescriptor.direction == .descending ? .ascending : .descending)
            : option.defaultDirection
        
        sortDescriptor = SortDescriptor(option: option, direction: newDirection)
        applySorting()
        
        // Compute rank changes for the new sort option
        if sortDescriptor.option == .playCount {
            rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
        } else {
            rankChanges.removeAll() // Clear when not sorting by play count
        }
        
        AppHaptics.selectionChanged()
        logger.log("Updated sorting to \(sortDescriptor.key)", level: .info)
    }
    
    private func applySorting() {
        switch sortDescriptor.option {
        case .playCount:
            if sortDescriptor.direction == .descending {
                // Use displayedPlayCount for sorting
                songs = allSongs.sorted { $0.displayedPlayCount > $1.displayedPlayCount }
            } else {
                songs = allSongs.sorted { $0.displayedPlayCount < $1.displayedPlayCount }
            }
        case .title:
            if sortDescriptor.direction == .ascending {
                songs = allSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            } else {
                songs = allSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
            }
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
