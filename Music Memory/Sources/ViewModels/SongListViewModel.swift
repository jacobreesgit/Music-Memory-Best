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
    @Published var enhancementStats: EnhancementStats = EnhancementStats(totalSongs: 0, enhancedSongs: 0, queuedSongs: 0, urgentRemaining: 0, highRemaining: 0, mediumRemaining: 0, lowRemaining: 0, backgroundRemaining: 0)
    
    private var allSongs: [Song] = [] // Store original unsorted songs
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let logger: LoggerProtocol
    private let rankHistoryService: RankHistoryServiceProtocol
    private let priorityService: EnhancementPriorityServiceProtocol
    
    // CRITICAL FIX: Add cache services
    private let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    private let cacheManagementService: CacheManagementServiceProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private var isAppLaunching = true
    let errorSubject = PassthroughSubject<AppError, Never>()
    
    // Enhancement control with better management
    private var enhancementTask: Task<Void, Never>?
    private var appIdleTimer: Timer?
    private var statsUpdateTimer: Timer?
    private var cacheValidationTimer: Timer?
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        logger: LoggerProtocol,
        rankHistoryService: RankHistoryServiceProtocol,
        priorityService: EnhancementPriorityServiceProtocol,
        enhancedSongCacheService: EnhancedSongCacheServiceProtocol,
        cacheManagementService: CacheManagementServiceProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.logger = logger
        self.rankHistoryService = rankHistoryService
        self.priorityService = priorityService
        self.enhancedSongCacheService = enhancedSongCacheService
        self.cacheManagementService = cacheManagementService
        
        setupErrorHandling()
        setupPlayCompletionListener()
        setupLocalDataClearedListener()
        setupAppLifecycleObservers()
        
        // Start periodic stats updates
        startStatsUpdateTimer()
        
        // CRITICAL FIX: Start cache validation timer
        startCacheValidationTimer()
        
        // Cleanup old snapshots on initialization (once per app launch)
        Task {
            await MainActor.run {
                rankHistoryService.cleanupOldSnapshots()
                
                // CRITICAL FIX: Perform cache validation and cleanup on launch
                performInitialCacheValidation()
            }
        }
    }
    
    deinit {
        enhancementTask?.cancel()
        appIdleTimer?.invalidate()
        statsUpdateTimer?.invalidate()
        cacheValidationTimer?.invalidate()
    }
    
    // CRITICAL FIX: Cache validation and management
    private func performInitialCacheValidation() {
        Task {
            // Validate caches on app launch
            let validationResult = cacheManagementService.validateAllCaches()
            
            if validationResult.totalProblems > 0 {
                logger.log("Found \(validationResult.totalProblems) cache problems on app launch", level: .warning)
                
                // Perform cleanup if there are significant problems
                if validationResult.totalProblems > 50 {
                    logger.log("Performing cleanup due to cache problems", level: .info)
                    cacheManagementService.performPeriodicCleanup()
                }
            }
        }
    }
    
    private func startCacheValidationTimer() {
        // Validate cache health every 5 minutes
        cacheValidationTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.validateCacheHealth()
        }
    }
    
    private func validateCacheHealth() {
        Task {
            let healthScore = cacheManagementService.getCacheHealthScore()
            
            if healthScore < 0.7 {
                logger.log("Cache health degraded (score: \(String(format: "%.2f", healthScore)))", level: .warning)
                
                if cacheManagementService.shouldPerformCleanup() {
                    logger.log("Performing automatic cache cleanup", level: .info)
                    cacheManagementService.performPeriodicCleanup()
                }
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
    
    private func setupAppLifecycleObservers() {
        // Monitor app state for idle detection
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppEnteredBackground()
            }
            .store(in: &cancellables)
    }
    
    private func startStatsUpdateTimer() {
        // Update stats every 2 seconds when enhancing
        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.enhancementProgress.isEnhancing else { return }
            
            Task { @MainActor in
                self.enhancementStats = self.priorityService.getEnhancementStats()
            }
        }
    }
    
    private func handleAppBecameActive() {
        // Reset idle state
        priorityService.setAppIdleState(false)
        
        // Start idle detection timer
        startIdleDetectionTimer()
        
        // Resume enhancement if needed
        resumeEnhancementIfNeeded()
        
        // CRITICAL FIX: Check for cache inconsistencies after app returns from background
        Task {
            let validationResult = cacheManagementService.validateAllCaches()
            if validationResult.totalProblems > 0 {
                logger.log("Found \(validationResult.totalProblems) cache problems after returning from background", level: .info)
            }
        }
    }
    
    private func handleAppEnteredBackground() {
        // Cancel enhancement task to save battery
        enhancementTask?.cancel()
        appIdleTimer?.invalidate()
        
        priorityService.setAppIdleState(false)
    }
    
    private func startIdleDetectionTimer() {
        appIdleTimer?.invalidate()
        
        // Consider app idle after 30 seconds of no interaction
        appIdleTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.priorityService.setAppIdleState(true)
            // Resume enhancement for background priority songs
            self?.resumeEnhancementIfNeeded()
        }
    }
    
    private func handleLocalDataCleared() {
        logger.log("Local data cleared - refreshing song list and caches", level: .info)
        
        // Clear rank changes since rank history was cleared
        rankChanges.removeAll()
        
        // Refresh the song list to reflect cleared local play counts
        applySorting()
        
        // Update priority service with new song states
        priorityService.updateSongsList(allSongs)
        
        // CRITICAL FIX: Reset enhancement progress since caches were cleared
        enhancementProgress = EnhancementProgress(totalCount: allSongs.count)
        enhancementStats = priorityService.getEnhancementStats()
        
        // Post notification to update Now Playing bar
        NotificationCenter.default.post(
            name: .songsListUpdated,
            object: nil,
            userInfo: [Notification.SongKeys.updatedSongs: songs]
        )
        
        // CRITICAL FIX: Restart enhancement since caches were cleared
        startOptimizedEnhancement()
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
            rankHistoryService.saveRankSnapshot(songs: songs, sortDescriptor: sortDescriptor)
            
            // 2. Apply sorting with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                applySorting()
            }
            
            // 3. Update priority service with new song order (non-blocking)
            priorityService.updateSongsList(allSongs)
            priorityService.setCurrentSortOrder(sortDescriptor)
            
            // 4. ALWAYS compute rank changes - this ensures indicators show up
            rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
            
            // 5. Post notification that songs list was updated
            NotificationCenter.default.post(
                name: .songsListUpdated,
                object: nil,
                userInfo: [Notification.SongKeys.updatedSongs: songs]
            )
            
            // 6. Ensure NowPlayingViewModel has the updated list
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
        
        logger.log("Loading songs with integrated caching system", level: .info)
        
        do {
            // Check current permission status first
            await updatePermissionStatus(musicLibraryService.checkPermissionStatus())
            
            // If permission is granted, load songs
            if permissionStatus == .granted {
                // CRITICAL FIX: Load songs with cache integration
                let songsWithCache = try await loadSongsWithCacheIntegration()
                
                // Sync play counts only on fresh app launch
                if isAppLaunching {
                    logger.log("App launching - syncing play counts", level: .info)
                    for song in songsWithCache {
                        song.syncPlayCounts(logger: logger)
                    }
                    isAppLaunching = false
                }
                
                // Show data immediately (MediaPlayer + cached enhancements)
                self.allSongs = songsWithCache
                applySorting()
                
                // Initialize priority service with songs and current sort order (non-blocking)
                priorityService.updateSongsList(allSongs)
                priorityService.setCurrentSortOrder(sortDescriptor)
                
                // CRITICAL FIX: Initialize enhancement progress based on actual cache state
                let cachedCount = allSongs.filter { enhancedSongCacheService.isSongEnhanced($0.id) }.count
                enhancementProgress = EnhancementProgress(totalCount: allSongs.count, enhancedCount: cachedCount)
                enhancementStats = priorityService.getEnhancementStats()
                
                // Compute initial rank changes when loading songs
                if sortDescriptor.option == .playCount {
                    rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
                }
                
                // Stop loading indicator - data is now visible
                isLoading = false
                
                logger.log("Loaded \(allSongs.count) songs (\(cachedCount) from cache) - starting intelligent enhancement", level: .info)
                
                // Initial notification to update Now Playing bar rank
                NotificationCenter.default.post(
                    name: .songsListUpdated,
                    object: nil,
                    userInfo: [Notification.SongKeys.updatedSongs: songs]
                )
                
                // Ensure NowPlayingViewModel has the current songs list
                NowPlayingViewModel.shared.updateSongsList(songs)
                
                // CRITICAL FIX: Start coordinated cache warmup and enhancement
                Task {
                    await startCoordinatedEnhancement()
                }
                
                // Start idle detection for background priority
                startIdleDetectionTimer()
            } else {
                isLoading = false
            }
        } catch {
            isLoading = false
            logger.log("Error loading songs: \(error.localizedDescription)", level: .error)
            handleError(error)
        }
    }
    
    // CRITICAL FIX: Integrated cache loading
    private func loadSongsWithCacheIntegration() async throws -> [Song] {
        guard await musicLibraryService.checkPermissionStatus() == .granted else {
            throw AppError.permissionDenied
        }
        
        // Use the music library service which now integrates with caching
        return try await musicLibraryService.fetchSongs()
    }
    
    // CRITICAL FIX: Coordinated enhancement that respects caches
    private func startCoordinatedEnhancement() async {
        // Check if we need cache warmup
        await cacheManagementService.coordinatedCacheWarmup(for: allSongs)
        
        // Start regular enhancement for remaining songs
        startOptimizedEnhancement()
    }
    
    private func startOptimizedEnhancement() {
        // Cancel any existing enhancement task
        enhancementTask?.cancel()
        
        // Start new enhancement task with optimized prioritization
        enhancementTask = Task {
            await runOptimizedEnhancement()
        }
    }
    
    private func runOptimizedEnhancement() async {
        logger.log("Starting optimized smart priority enhancement with cache integration", level: .info)
        
        var completedBatches = 0
        let maxBatchesBeforeBreak = 3 // Smaller batches, more frequent breaks
        
        while !Task.isCancelled {
            // Get next priority batch (non-blocking call) - this now respects caching
            let enhancedSongs = await musicLibraryService.enhanceSongsBatch(batchSize: 3)
            
            if enhancedSongs.isEmpty {
                // No more songs to enhance
                await MainActor.run {
                    enhancementProgress.isComplete = true
                    logger.log("Optimized smart priority enhancement completed", level: .info)
                }
                break
            }
            
            // Update UI with enhanced songs
            await MainActor.run {
                updateEnhancedSongs(enhancedSongs)
            }
            
            completedBatches += 1
            
            // Take frequent breaks to avoid blocking
            if completedBatches >= maxBatchesBeforeBreak {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms break
                completedBatches = 0
            } else {
                // Very short delay between batches
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            }
        }
    }
    
    private func resumeEnhancementIfNeeded() {
        // Only resume if we're not complete and don't already have a running task
        guard !enhancementProgress.isComplete,
              enhancementTask?.isCancelled != false else { return }
        
        logger.log("Resuming optimized smart priority enhancement", level: .debug)
        startOptimizedEnhancement()
    }
    
    @MainActor
    private func updateEnhancedSongs(_ enhancedSongs: [Song]) {
        var hasChanges = false
        
        for enhancedSong in enhancedSongs {
            // Find and replace the song in allSongs
            if let index = allSongs.firstIndex(where: { $0.id == enhancedSong.id }) {
                allSongs[index] = enhancedSong
                hasChanges = true
                
                // CRITICAL FIX: Only increment if not already enhanced
                if !enhancedSongCacheService.isSongEnhanced(enhancedSong.id) {
                    enhancementProgress.enhancedCount += 1
                }
                
                logger.log("Smart enhancement: Updated '\(enhancedSong.title)' (\(enhancementProgress.enhancedCount)/\(enhancementProgress.totalCount))", level: .debug)
            }
        }
        
        if hasChanges {
            // Re-apply sorting with the updated songs
            applySorting()
            
            // Update enhancement stats (non-blocking)
            enhancementStats = priorityService.getEnhancementStats()
            
            // Update NowPlayingViewModel if any current song was enhanced
            if let currentSongId = NowPlayingViewModel.shared.currentSong?.id,
               enhancedSongs.contains(where: { $0.id == currentSongId }) {
                NowPlayingViewModel.shared.updateSongsList(songs)
                
                // Notify NowPlayingViewModel to refresh artwork
                NotificationCenter.default.post(name: .songEnhanced, object: nil)
            }
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
        
        // Update priority service with new sort order (non-blocking)
        priorityService.setCurrentSortOrder(sortDescriptor)
        
        // Update stats (non-blocking)
        Task { @MainActor in
            enhancementStats = priorityService.getEnhancementStats()
        }
        
        // Compute rank changes for the new sort option
        if sortDescriptor.option == .playCount {
            rankChanges = rankHistoryService.getRankChanges(for: songs, sortDescriptor: sortDescriptor)
        } else {
            rankChanges.removeAll() // Clear when not sorting by play count
        }
        
        // Update NowPlayingViewModel with the new sorted list
        NowPlayingViewModel.shared.updateSongsList(songs)
        
        // Resume enhancement with new priorities
        resumeEnhancementIfNeeded()
        
        // Reset idle timer since user interacted
        startIdleDetectionTimer()
        
        AppHaptics.selectionChanged()
        logger.log("Updated sorting to \(sortDescriptor.key) - reprioritizing enhancement queue", level: .info)
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
    
    // MARK: - Cache Management Methods
    
    func getCacheStatistics() -> CacheStatistics {
        return cacheManagementService.getCacheStatistics()
    }
    
    func getCacheHealthScore() -> Double {
        return cacheManagementService.getCacheHealthScore()
    }
    
    func performManualCacheCleanup() {
        Task {
            cacheManagementService.performPeriodicCleanup()
            
            // Refresh stats after cleanup
            await MainActor.run {
                enhancementStats = priorityService.getEnhancementStats()
            }
        }
    }
}

// MARK: - Enhancement Progress Tracking (Updated)

struct EnhancementProgress {
    var totalCount: Int = 0
    var enhancedCount: Int = 0
    var isComplete: Bool = false
    
    init(totalCount: Int = 0, enhancedCount: Int = 0) {
        self.totalCount = totalCount
        self.enhancedCount = enhancedCount
        self.isComplete = false
    }
    
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

// MARK: - Notification for Song Enhancement

extension NSNotification.Name {
    static let songEnhanced = NSNotification.Name("songEnhanced")
}
