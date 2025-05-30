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
    @Published var isLoading: Bool = false // Only for initial permission/MediaPlayer load
    @Published var permissionStatus: AppPermissionStatus = .unknown
    @Published var sortDescriptor = SortDescriptor(option: .playCount, direction: .descending)
    @Published var rankChanges: [String: RankChange] = [:]
    @Published var enhancementProgress: EnhancementProgress = EnhancementProgress()
    
    private var allSongs: [Song] = [] // Store original unsorted songs
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let logger: LoggerProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isAppLaunching = true
    let errorSubject = PassthroughSubject<AppError, Never>()
    
    // Progressive loading subjects
    private let songEnhancedSubject = PassthroughSubject<Song, Never>()
    
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
        setupProgressiveEnhancement()
        
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
    
    private func setupProgressiveEnhancement() {
        // Listen for individual song enhancements
        songEnhancedSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] enhancedSong in
                self?.handleSongEnhanced(enhancedSong)
            }
            .store(in: &cancellables)
    }
    
    private func handleSongEnhanced(_ enhancedSong: Song) {
        // Find and replace the song in allSongs
        if let index = allSongs.firstIndex(where: { $0.id == enhancedSong.id }) {
            allSongs[index] = enhancedSong
            
            // Re-apply sorting with the updated song
            applySorting()
            
            // Update enhancement progress
            enhancementProgress.enhancedCount += 1
            
            // Update NowPlayingViewModel if this is the current song
            if NowPlayingViewModel.shared.currentSong?.id == enhancedSong.id {
                NowPlayingViewModel.shared.updateSongsList(songs)
            }
            
            logger.log("Progressive enhancement: Updated '\(enhancedSong.title)' (\(enhancementProgress.enhancedCount)/\(enhancementProgress.totalCount))", level: .debug)
        }
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
        
        // Always handle play count updates and re-sorting, regardless of how the song was played
        if sortDescriptor.option == .playCount {
            logger.log("Re-sorting list after play count increment for '\(song.title)'", level: .info)
            
            // 1. ALWAYS save current state before re-sorting - this is the key fix!
            // We need to save the snapshot regardless of single song or queue play
            rankHistoryService.saveRankSnapshot(songs: songs, sortDescriptor: sortDescriptor)
            
            // 2. Apply sorting with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                applySorting()
            }
            
            // 3. ALWAYS compute rank changes - this ensures indicators show up
            rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
            
            // 4. Post notification that songs list was updated
            NotificationCenter.default.post(
                name: .songsListUpdated,
                object: nil,
                userInfo: [Notification.SongKeys.updatedSongs: songs]
            )
            
            // 5. Ensure NowPlayingViewModel has the updated list
            NowPlayingViewModel.shared.updateSongsList(songs)
            
            // Log position change if any
            if let newIndex = songs.firstIndex(where: { $0.id == songId }) {
                let newRank = newIndex + 1
                if let oldRank = previousRank, oldRank != newRank {
                    logger.log("Song '\(song.title)' moved from rank #\(oldRank) to #\(newRank)", level: .info)
                } else if previousRank == nil {
                    logger.log("Song '\(song.title)' now at rank #\(newRank) (was not in previous ranking)", level: .info)
                }
            }
        } else {
            // Even if not sorting by play count, still notify that the song list was updated
            // so that play count displays are refreshed
            NotificationCenter.default.post(
                name: .songsListUpdated,
                object: nil,
                userInfo: [Notification.SongKeys.updatedSongs: songs]
            )
            
            // Ensure NowPlayingViewModel has the updated list
            NowPlayingViewModel.shared.updateSongsList(songs)
        }
    }
    
    @MainActor
    func loadSongs() async {
        // Only show loading for permission check and initial MediaPlayer fetch
        isLoading = true
        
        logger.log("Loading songs with progressive enhancement", level: .info)
        
        do {
            // Check current permission status first
            await updatePermissionStatus(musicLibraryService.checkPermissionStatus())
            
            // If permission is granted, load songs
            if permissionStatus == .granted {
                // Step 1: Load MediaPlayer songs immediately (no loading screen)
                let mediaPlayerSongs = try await loadMediaPlayerSongs()
                
                // Sync play counts only on fresh app launch
                if isAppLaunching {
                    logger.log("App launching - syncing play counts", level: .info)
                    for song in mediaPlayerSongs {
                        song.syncPlayCounts(logger: logger)
                    }
                    isAppLaunching = false
                }
                
                // Step 2: Show MediaPlayer data immediately
                self.allSongs = mediaPlayerSongs
                applySorting()
                
                // Initialize enhancement progress
                enhancementProgress = EnhancementProgress(totalCount: mediaPlayerSongs.count)
                
                // Compute initial rank changes when loading songs
                if sortDescriptor.option == .playCount {
                    rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
                }
                
                // Stop loading indicator - data is now visible
                isLoading = false
                
                logger.log("Loaded \(mediaPlayerSongs.count) songs from MediaPlayer - starting progressive enhancement", level: .info)
                
                // Initial notification to update Now Playing bar rank
                NotificationCenter.default.post(
                    name: .songsListUpdated,
                    object: nil,
                    userInfo: [Notification.SongKeys.updatedSongs: songs]
                )
                
                // Ensure NowPlayingViewModel has the current songs list
                NowPlayingViewModel.shared.updateSongsList(songs)
                
                // Step 3: Start progressive MusicKit enhancement in background
                Task {
                    await startProgressiveEnhancement(songs: mediaPlayerSongs)
                }
            } else {
                isLoading = false
            }
        } catch {
            isLoading = false
            logger.log("Error loading songs: \(error.localizedDescription)", level: .error)
            handleError(error)
        }
    }
    
    private func loadMediaPlayerSongs() async throws -> [Song] {
        // This method extracts just the MediaPlayer loading logic
        // for immediate display without MusicKit enhancement
        guard await musicLibraryService.checkPermissionStatus() == .granted else {
            throw AppError.permissionDenied
        }
        
        // Use the MusicLibraryService but request only MediaPlayer data for immediate display
        // We'll enhance with MusicKit progressively
        return try await musicLibraryService.fetchSongs()
    }
    
    private func startProgressiveEnhancement(songs: [Song]) async {
        // Run MusicKit enhancement in background without blocking UI
        logger.log("Starting progressive MusicKit enhancement for \(songs.count) songs", level: .info)
        
        // Process songs in smaller batches to provide more frequent updates
        let batchSize = 10
        let batches = songs.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            logger.log("Processing enhancement batch \(batchIndex + 1)/\(batches.count) with \(batch.count) songs", level: .debug)
            
            // Process batch and stream results
            await processBatchProgressively(batch)
            
            // Rate limiting delay between batches
            if batchIndex < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            }
        }
        
        await MainActor.run {
            enhancementProgress.isComplete = true
            logger.log("Progressive MusicKit enhancement completed: \(enhancementProgress.enhancedCount)/\(enhancementProgress.totalCount) enhanced", level: .info)
        }
    }
    
    private func processBatchProgressively(_ batch: [Song]) async {
        // Process each song in the batch and immediately stream results
        for song in batch {
            if let enhancedSong = await enhanceSongWithMusicKit(song) {
                // Stream the enhanced song immediately
                await MainActor.run {
                    songEnhancedSubject.send(enhancedSong)
                }
            } else {
                // Even if enhancement failed, update progress
                await MainActor.run {
                    enhancementProgress.enhancedCount += 1
                }
            }
            
            // Small delay between individual songs to prevent overwhelming the UI
            try? await Task.sleep(nanoseconds: 25_000_000) // 25ms delay
        }
    }
    
    private func enhanceSongWithMusicKit(_ song: Song) async -> Song? {
        // Use the MusicLibraryService to enhance individual songs
        return await musicLibraryService.enhanceSongWithMusicKit(song)
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
        
        // Update NowPlayingViewModel with the new sorted list
        NowPlayingViewModel.shared.updateSongsList(songs)
        
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

// MARK: - Enhancement Progress Tracking

struct EnhancementProgress {
    var totalCount: Int = 0
    var enhancedCount: Int = 0
    var isComplete: Bool = false
    
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(enhancedCount) / Double(totalCount)
    }
    
    var isEnhancing: Bool {
        return totalCount > 0 && enhancedCount < totalCount && !isComplete
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
