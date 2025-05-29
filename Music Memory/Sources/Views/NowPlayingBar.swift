import SwiftUI
import MediaPlayer
import Combine
import AVFoundation

struct NowPlayingBar: View {
    @ObservedObject private var viewModel = NowPlayingViewModel.shared
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var currentImage: UIImage?
    @State private var isPressed = false
    
    // Computed property to determine if we should allow navigation
    private var shouldAllowNavigation: Bool {
        guard let currentSong = viewModel.currentSong else { return false }
        
        // Check if we're currently viewing THIS specific song's detail page
        return navigationManager.currentDetailSong?.id != currentSong.id
    }
    
    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.small) {
                    // Clickable area: Artwork, rank, song info, and spacer
                    HStack(spacing: AppSpacing.small) {
                        // Custom artwork display logic matched exactly with ArtworkView
                        Group {
                            if let image = currentImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "music.note")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(45 / 4)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        .frame(width: 45, height: 45)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(AppRadius.small)
                        
                        // Rank number - using dynamic width based on digit count
                        if let rank = viewModel.currentSongRank {
                            Text("\(rank)")
                                .font(AppFonts.callout)
                                .fontWeight(AppFontWeight.semibold)
                                .foregroundColor(AppColors.primary)
                                .frame(width: rank >= 1000 ? 47 : 37, alignment: .center)
                        }
                        
                        // Song info - Using smaller design system text components for compact space
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            Text(viewModel.title)
                                .font(AppFonts.callout)
                                .fontWeight(AppFontWeight.medium)
                                .foregroundColor(AppColors.primaryText)
                                .lineLimit(1)
                            
                            HStack(spacing: AppSpacing.tiny) {
                                Text(viewModel.artist)
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .lineLimit(1)
                                
                                if let currentSong = viewModel.currentSong {
                                    Text("•")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    
                                    Text("\(currentSong.displayedPlayCount) plays")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        // Spacer is now part of the clickable area
                        Spacer()
                    }
                    // Apply navigation gestures to the entire left area including spacer
                    .contentShape(Rectangle()) // Make the entire area tappable
                    .scaleEffect(isPressed ? 0.98 : 1.0) // Visual feedback for press
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                    .onLongPressGesture(
                        minimumDuration: 0.5,
                        maximumDistance: 50
                    ) {
                        // Long press action - navigate to song detail view only if not already viewing it
                        if shouldAllowNavigation {
                            navigateToSongDetail()
                        } else {
                            // Provide error feedback that navigation is not available (already on that song's detail)
                            AppHaptics.error()
                        }
                    } onPressingChanged: { pressing in
                        // Handle press state changes
                        isPressed = pressing
                        
                        if pressing {
                            if shouldAllowNavigation {
                                // Provide medium impact feedback when long press begins and navigation is allowed
                                AppHaptics.mediumImpact()
                            } else {
                                // Provide light feedback when navigation is not allowed
                                AppHaptics.lightImpact()
                            }
                        }
                    }
                    .simultaneousGesture(
                        // Add a tap gesture for quick access
                        TapGesture()
                            .onEnded { _ in
                                // Quick tap - navigate only if allowed
                                if shouldAllowNavigation {
                                    navigateToSongDetail()
                                } else {
                                    // Provide error feedback that navigation is not available (already on that song's detail)
                                    AppHaptics.error()
                                }
                            }
                    )
                    
                    // Right side: Playback control buttons (NOT clickable for navigation)
                    HStack(spacing: 0) {
                        // Play/Pause button
                        Button(action: {
                            AppHaptics.mediumImpact()
                            viewModel.togglePlayback()
                        }) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.primaryText)
                                .frame(width: 44, height: 44)
                        }
                        
                        // Next button
                        Button(action: {
                            AppHaptics.lightImpact()
                            viewModel.skipToNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.primaryText)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                .padding(.leading, 20) // Specify left padding
                .padding(.trailing, 16) // Specify right padding
                .padding(.vertical, AppSpacing.small)
                .background(.ultraThinMaterial)
                .cornerRadius(AppRadius.medium)
                .appShadow(AppShadow.medium)
                .padding(.horizontal, AppSpacing.medium)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: viewModel.isVisible)
            .onChange(of: viewModel.currentImage) { oldValue, newValue in
                updateCurrentImage(newValue)
            }
            .onAppear {
                updateCurrentImage(viewModel.currentImage)
            }
        }
    }
    
    private func navigateToSongDetail() {
        // Navigate to song detail view when the now playing bar is interacted with
        guard let currentSong = viewModel.currentSong else { return }
        
        // Double-check that navigation is allowed (defensive programming)
        guard shouldAllowNavigation else { return }
        
        // Provide success haptic feedback for successful navigation
        AppHaptics.success()
        
        navigationManager.navigateToSongDetail(song: currentSong)
    }
    
    private func updateCurrentImage(_ image: UIImage?) {
        currentImage = image
    }
}

class NowPlayingViewModel: ObservableObject {
    // Shared instance for easier access
    static let shared = NowPlayingViewModel()
    
    // Music player
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    
    // Published properties
    @Published var isVisible = false
    @Published var isPlaying = false
    @Published var title = "Not Playing"
    @Published var artist = ""
    @Published var currentArtwork: MPMediaItemArtwork?
    @Published var currentSong: Song?
    @Published var currentSongRank: Int?
    @Published var currentImage: UIImage? // Make this published for external observation
    
    // Store the songs list to compute rank
    private var songs: [Song] = []
    
    // Play completion tracking
    private var previousSong: Song?
    private var songStartTime: Date?
    private var hasTrackedCurrentSong = false
    private var lastPlaybackPosition: TimeInterval = 0
    
    private var logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    private var artworkPersistenceService: ArtworkPersistenceServiceProtocol?
    
    init() {
        // Get artwork persistence service from DI container
        artworkPersistenceService = DIContainer.shared.artworkPersistenceService
        
        setupObservers()
        checkCurrentlyPlaying()
        
        // Try to load saved artwork on initialization
        loadSavedArtworkIfNeeded()
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
        playbackTimer?.invalidate()
    }
    
    func updateSongsList(_ songs: [Song]) {
        self.songs = songs
        // Recompute rank for current song if there is one
        if let currentSong = currentSong {
            updateRankForSong(currentSong)
        }
    }
    
    private func updateRankForSong(_ song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            currentSongRank = index + 1 // Convert to 1-based ranking
        } else {
            currentSongRank = nil
        }
    }
    
    private func loadSavedArtworkIfNeeded() {
        guard let artworkService = artworkPersistenceService else { return }
        guard let song = currentSong else { return }
        
        // Only try to load saved artwork if we don't already have artwork loaded
        if currentImage == nil {
            if let savedArtwork = artworkService.loadSavedArtwork(for: song.id) {
                logger.log("Loaded saved artwork for song: '\(song.title)'", level: .info)
                DispatchQueue.main.async {
                    self.currentImage = savedArtwork
                }
            }
        }
    }
    
    /// Called by AppLifecycleManager to check if artwork should be restored
    func checkForArtworkRestoration() {
        // This method can be called when the app becomes active
        // to ensure saved artwork is properly restored
        if let _ = currentSong, currentImage == nil {
            loadSavedArtworkIfNeeded()
        }
    }
    
    private func activateAudioSessionIfNeeded() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Only activate when we're about to play music
            try audioSession.setActive(true)
            logger.log("Audio session activated for playback", level: .debug)
        } catch {
            logger.log("Failed to activate audio session: \(error.localizedDescription)", level: .error)
        }
    }
    
    func setupObservers() {
        // Begin generating notifications
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        // Observe playback state changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange, object: musicPlayer)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handlePlaybackStateChange()
            }
            .store(in: &cancellables)
        
        // Observe now playing item changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange, object: musicPlayer)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleNowPlayingItemChange()
            }
            .store(in: &cancellables)
        
        // Listen for list updates to update rank
        NotificationCenter.default.publisher(for: .songsListUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let updatedSongs = notification.userInfo?[Notification.SongKeys.updatedSongs] as? [Song] {
                    self?.updateSongsList(updatedSongs)
                }
            }
            .store(in: &cancellables)
    }
    
    func checkCurrentlyPlaying() {
        updatePlaybackState()
        updateNowPlayingItem()
    }
    
    func updatePlaybackState() {
        let wasPlaying = isPlaying
        isPlaying = musicPlayer.playbackState == .playing
        
        // Start or stop playback position monitoring
        if isPlaying && !wasPlaying {
            startPlaybackPositionMonitoring()
        } else if !isPlaying && wasPlaying {
            stopPlaybackPositionMonitoring()
        }
    }
    
    func handlePlaybackStateChange() {
        updatePlaybackState()
    }
    
    private func startPlaybackPositionMonitoring() {
        stopPlaybackPositionMonitoring() // Ensure no duplicate timers
        
        // Monitor playback position every 0.5 seconds
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPlaybackPosition()
        }
    }
    
    private func stopPlaybackPositionMonitoring() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func checkPlaybackPosition() {
        let currentPosition = musicPlayer.currentPlaybackTime
        
        // If playback position decreased significantly (more than 2 seconds), it's likely a new song
        if currentPosition < lastPlaybackPosition - 2.0 {
            // Position jumped backward - likely a new song started
            logger.log("Playback position jumped from \(lastPlaybackPosition) to \(currentPosition)", level: .debug)
        }
        
        lastPlaybackPosition = currentPosition
    }
    
    private func handleNowPlayingItemChange() {
        let previousItem = currentSong
        let currentItem = musicPlayer.nowPlayingItem
        
        // Check if a song actually completed (not just paused or manually changed)
        if let prevSong = previousItem,
           prevSong.mediaItem != currentItem,
           !hasTrackedCurrentSong {
            
            // Get the duration of the previous song
            let duration = prevSong.mediaItem.playbackDuration
            
            // Check if we were near the end of the song (within last 5 seconds)
            let wasNearEnd = lastPlaybackPosition > 0 && lastPlaybackPosition >= duration - 5.0
            
            if wasNearEnd || (songStartTime != nil && Date().timeIntervalSince(songStartTime!) >= duration - 5.0) {
                // Song completed naturally
                logger.log("Song '\(prevSong.title)' completed naturally", level: .info)
                
                // Increment local play count
                prevSong.incrementLocalPlayCount()
                
                // Provide haptic feedback
                AppHaptics.success()
                
                // Post notification for song completion
                NotificationCenter.default.post(
                    name: .songPlayCompleted,
                    object: nil,
                    userInfo: [Notification.SongKeys.completedSongId: prevSong.id]
                )
                
                hasTrackedCurrentSong = true
            } else {
                logger.log("Song '\(prevSong.title)' was skipped at position \(lastPlaybackPosition) of \(duration)", level: .debug)
            }
        }
        
        // Update to new song
        updateNowPlayingItem()
        
        // Reset tracking for new song
        if currentItem != nil && currentItem != previousItem?.mediaItem {
            hasTrackedCurrentSong = false
            songStartTime = Date()
            lastPlaybackPosition = 0
        }
    }
    
    func updateNowPlayingItem() {
        let currentItem = musicPlayer.nowPlayingItem
        
        if let mediaItem = currentItem {
            title = mediaItem.title ?? "Unknown Title"
            artist = mediaItem.artist ?? "Unknown Artist"
            currentArtwork = mediaItem.artwork
            currentSong = Song(from: mediaItem)
            
            // Update rank based on current song
            if let song = currentSong {
                updateRankForSong(song)
            }
            
            // Try to load saved artwork first, then fall back to system artwork
            if currentSong != nil {
                loadSavedArtworkIfNeeded()
            }
            
            // Update artwork - this will either use saved artwork or load from system
            updateArtwork(currentArtwork)
            
            isVisible = true
        } else {
            isVisible = false
            currentSong = nil
            currentArtwork = nil
            currentImage = nil
            currentSongRank = nil
            songStartTime = nil
            hasTrackedCurrentSong = false
        }
    }
    
    private func updateArtwork(_ artwork: MPMediaItemArtwork?) {
        // Only update from system artwork if we don't already have saved artwork loaded
        if currentImage == nil {
            if let artwork = artwork {
                currentImage = artwork.image(at: CGSize(width: 45, height: 45))
            } else {
                currentImage = nil
            }
        } else {
            // We have saved artwork loaded, but system artwork became available
            // Update with system artwork and clear saved artwork to prevent future conflicts
            if let artwork = artwork {
                let systemImage = artwork.image(at: CGSize(width: 45, height: 45))
                if systemImage != nil {
                    currentImage = systemImage
                    // Clear saved artwork since system artwork is now available
                    artworkPersistenceService?.clearSavedArtwork()
                    logger.log("System artwork loaded, cleared saved artwork", level: .debug)
                }
            }
        }
    }
    
    func togglePlayback() {
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
        } else {
            // Activate audio session before resuming playback
            activateAudioSessionIfNeeded()
            musicPlayer.play()
        }
    }
    
    func playSong(_ song: Song, fromQueue songs: [Song]? = nil) {
        // Reset tracking when manually playing a new song
        hasTrackedCurrentSong = false
        songStartTime = Date()
        lastPlaybackPosition = 0
        
        // Clear saved artwork when manually starting a new song
        artworkPersistenceService?.clearSavedArtwork()
        
        // Activate audio session before playing
        activateAudioSessionIfNeeded()
        
        if let queueSongs = songs {
            // Playing from a queue (like song list) - set up the entire queue
            logger.log("Playing song '\(song.title)' from queue with \(queueSongs.count) songs", level: .info)
            
            // Find the index of the selected song in the queue
            guard let startIndex = queueSongs.firstIndex(where: { $0.id == song.id }) else {
                logger.log("Song not found in provided queue", level: .error)
                // Fallback to single song playback
                playSingleSong(song)
                return
            }
            
            // Create queue starting from the selected song
            let queueFromSong = Array(queueSongs[startIndex...])
            let mediaItems = queueFromSong.map { $0.mediaItem }
            let descriptor = MPMediaItemCollection(items: mediaItems)
            
            musicPlayer.setQueue(with: descriptor)
            musicPlayer.prepareToPlay()
            musicPlayer.play()
        } else {
            // Playing a single song (like from detail view)
            playSingleSong(song)
        }
    }
    
    private func playSingleSong(_ song: Song) {
        logger.log("Playing single song: '\(song.title)'", level: .info)
        // Set the queue with just this song
        let descriptor = MPMediaItemCollection(items: [song.mediaItem])
        musicPlayer.setQueue(with: descriptor)
        musicPlayer.prepareToPlay()
        musicPlayer.play()
    }
    
    func skipToNext() {
        logger.log("Skipping to next track", level: .info)
        // Mark current song as tracked to prevent false completion
        hasTrackedCurrentSong = true
        // Clear saved artwork when skipping
        artworkPersistenceService?.clearSavedArtwork()
        musicPlayer.skipToNextItem()
    }
    
    func skipToPrevious() {
        logger.log("Skipping to previous track", level: .info)
        // Mark current song as tracked to prevent false completion
        hasTrackedCurrentSong = true
        // Clear saved artwork when skipping
        artworkPersistenceService?.clearSavedArtwork()
        musicPlayer.skipToPreviousItem()
    }
}
