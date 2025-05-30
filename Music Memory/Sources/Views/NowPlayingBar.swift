import SwiftUI
@preconcurrency import MediaPlayer
import Combine
import AVFoundation
import MusicKit

struct NowPlayingBar: View {
    @ObservedObject private var viewModel = NowPlayingViewModel.shared
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var currentImage: UIImage?
    @State private var isPressed = false
    @State private var dominantColor: Color = AppColors.primary
    
    // Computed property to determine if we should allow navigation
    private var shouldAllowNavigation: Bool {
        guard let currentSong = viewModel.currentSong else { return false }
        return navigationManager.currentDetailSong?.id != currentSong.id
    }
    
    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
                nowPlayingContent
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(nowPlayingBackground)
                    .cornerRadius(AppRadius.medium)
                    .appShadow(AppShadow.medium)
                    .padding(.horizontal, 8)
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
    
    private var nowPlayingContent: some View {
        HStack(spacing: AppSpacing.small) {
            clickableArea
            
            Spacer()
            
            playbackControls
        }
    }
    
    private var clickableArea: some View {
        HStack(spacing: AppSpacing.small) {
            artworkView
            
            if let rank = viewModel.currentSongRank {
                rankText(rank)
            }
            
            songInfoView
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 50
        ) {
            handleLongPress()
        } onPressingChanged: { pressing in
            handlePressChange(pressing)
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                handleTap()
            }
        )
    }
    
    private var artworkView: some View {
        // Use enhanced artwork view with MusicKit support and progressive loading
        NowPlayingArtworkView(song: viewModel.currentSong)
    }
    
    private func rankText(_ rank: Int) -> some View {
        Text("\(rank)")
            .font(AppFonts.callout)
            .fontWeight(AppFontWeight.semibold)
            .foregroundColor(AppColors.primary)
            .frame(width: rank >= 1000 ? 47 : 37, alignment: .center)
    }
    
    private var songInfoView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
            // Song title - removed sparkles indicator
            Text(viewModel.title)
                .font(AppFonts.callout)
                .fontWeight(AppFontWeight.medium)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
            
            songSubtitleView
        }
    }
    
    private var songSubtitleView: some View {
        HStack(spacing: AppSpacing.tiny) {
            Text(viewModel.artist)
                .font(AppFonts.detail)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(1)
            
            if let currentSong = viewModel.currentSong {
                Text("•")
                    .font(AppFonts.detail)
                    .foregroundColor(AppColors.secondaryText)
                
                Text("\(currentSong.displayedPlayCount) plays")
                    .font(AppFonts.detail)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 0) {
            Button(action: {
                AppHaptics.mediumImpact()
                viewModel.togglePlayback()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.primaryText)
                    .frame(width: 44, height: 44)
            }
            
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
    
    private var nowPlayingBackground: some View {
        ZStack {
            // Lighter base background to block content behind
            AppColors.background
                .opacity(0.675)
            
            // More prominent artwork color gradient on top
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.7),
                    dominantColor.opacity(0.5),
                    dominantColor.opacity(0.35),
                    dominantColor.opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            
            // Light material for texture without transparency
            Color.clear
                .background(.regularMaterial.opacity(0.9))
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(dominantColor.opacity(0.5), lineWidth: 1.0)
        )
        .animation(.easeInOut(duration: 0.6), value: dominantColor)
    }
    
    // MARK: - Actions
    
    private func handleLongPress() {
        if shouldAllowNavigation {
            navigateToSongDetail()
        } else {
            AppHaptics.error()
        }
    }
    
    private func handleTap() {
        if shouldAllowNavigation {
            navigateToSongDetail()
        } else {
            AppHaptics.error()
        }
    }
    
    private func handlePressChange(_ pressing: Bool) {
        isPressed = pressing
        
        if pressing {
            if shouldAllowNavigation {
                AppHaptics.mediumImpact()
            } else {
                AppHaptics.lightImpact()
            }
        }
    }
    
    private func navigateToSongDetail() {
        guard let currentSong = viewModel.currentSong else { return }
        guard shouldAllowNavigation else { return }
        
        AppHaptics.success()
        navigationManager.navigateToSongDetail(song: currentSong)
    }
    
    private func updateCurrentImage(_ image: UIImage?) {
        currentImage = image
        
        if let image = image {
            dominantColor = extractDominantColor(from: image) ?? AppColors.primary
        } else {
            dominantColor = AppColors.primary
        }
    }
    
    // MARK: - Color Extraction (Simplified)
    
    private func extractDominantColor(from image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Simple center pixel sampling for performance
        let width = cgImage.width
        let height = cgImage.height
        let centerX = width / 2
        let centerY = height / 2
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: -centerX, y: -centerY, width: width, height: height))
        
        guard let data = context?.data else { return nil }
        let pixelData = data.assumingMemoryBound(to: UInt8.self)
        
        let red = CGFloat(pixelData[0]) / 255.0
        let green = CGFloat(pixelData[1]) / 255.0
        let blue = CGFloat(pixelData[2]) / 255.0
        
        // Enhance the color slightly
        let enhancedColor = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        enhancedColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost saturation and brightness more for better visual impact
        let boostedSaturation = min(1.0, saturation * 1.8)
        let adjustedBrightness = brightness < 0.3 ? min(1.0, brightness * 1.8) : max(0.6, brightness)
        
        let finalColor = UIColor(hue: hue, saturation: boostedSaturation, brightness: adjustedBrightness, alpha: alpha)
        
        return Color(finalColor)
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
    
    // Non-library song detection
    private var isCurrentSongFromLibrary = true
    
    private var logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    private var artworkPersistenceService: ArtworkPersistenceServiceProtocol?
    private var priorityService: EnhancementPriorityServiceProtocol?
    
    init() {
        // Get services from DI container
        artworkPersistenceService = DIContainer.shared.artworkPersistenceService
        priorityService = DIContainer.shared.enhancementPriorityService
        
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
        // This method can be called when the app becomes active to ensure saved artwork is properly restored
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
        
        // Listen for song enhancement updates
        NotificationCenter.default.publisher(for: .songEnhanced)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSongEnhancementUpdate()
            }
            .store(in: &cancellables)
    }
    
    private func handleSongEnhancementUpdate() {
        // Refresh current song data and artwork when enhancement occurs
        if let currentMediaItem = musicPlayer.nowPlayingItem,
           let enhancedSong = songs.first(where: { $0.mediaItem.persistentID == currentMediaItem.persistentID }) {
            
            // Update current song with enhanced data
            currentSong = enhancedSong
            title = enhancedSong.title
            artist = enhancedSong.enhancedArtist
            
            // Clear current image to force reload with enhanced artwork
            currentImage = nil
            updateEnhancedArtwork()
            
            logger.log("Updated now playing with enhanced data for '\(enhancedSong.title)'", level: .debug)
        }
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
            
            // Get the duration of the previous song using enhanced duration
            let duration = prevSong.enhancedDuration
            
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
            // Check if this song is in our library
            let isInLibrary = songs.contains { $0.mediaItem.persistentID == mediaItem.persistentID }
            isCurrentSongFromLibrary = isInLibrary
            
            // Find the enhanced Song object from our songs list first
            if let enhancedSong = songs.first(where: { $0.mediaItem.persistentID == mediaItem.persistentID }) {
                currentSong = enhancedSong
                title = enhancedSong.title
                artist = enhancedSong.enhancedArtist // Use enhanced artist name
                
                logger.log("Now playing (from library): '\(enhancedSong.title)' by '\(enhancedSong.enhancedArtist)'", level: .debug)
            } else {
                // Create a basic Song object if not found in our list (non-library song)
                let basicSong = Song(from: mediaItem)
                currentSong = basicSong
                title = basicSong.title
                artist = basicSong.enhancedArtist
                
                logger.log("Now playing (NOT in library): '\(basicSong.title)' by '\(basicSong.enhancedArtist)' - needs urgent enhancement", level: .info)
            }
            
            currentArtwork = mediaItem.artwork
            
            // Update rank based on current song (only for library songs)
            if let song = currentSong, isCurrentSongFromLibrary {
                updateRankForSong(song)
            } else {
                currentSongRank = nil // No rank for non-library songs
            }
            
            // Notify priority service about currently playing song (non-blocking)
            if let song = currentSong {
                priorityService?.setCurrentlyPlayingSong(song, isFromLibrary: isCurrentSongFromLibrary)
            }
            
            // Clear current artwork to force fresh load
            currentImage = nil
            
            // Try to load saved artwork first, then fall back to enhanced artwork loading
            if currentSong != nil {
                loadSavedArtworkIfNeeded()
            }
            
            // Update artwork with MusicKit enhancement (especially important for non-library songs)
            updateEnhancedArtwork()
            
            isVisible = true
        } else {
            isVisible = false
            currentSong = nil
            currentArtwork = nil
            currentImage = nil
            currentSongRank = nil
            songStartTime = nil
            hasTrackedCurrentSong = false
            isCurrentSongFromLibrary = true
            
            // Clear priority service current song (non-blocking)
            priorityService?.setCurrentlyPlayingSong(nil, isFromLibrary: true)
        }
    }
    
    private func updateEnhancedArtwork() {
        // Skip if we already have saved artwork loaded
        if currentImage != nil {
            return
        }
        
        guard let song = currentSong else { return }
        
        Task {
            await loadEnhancedArtworkAsync(for: song)
        }
    }
    
    @MainActor
    private func loadEnhancedArtworkAsync(for song: Song) {
        // Try MusicKit artwork first (higher quality) - especially important for non-library songs
        if let enhancedArtwork = song.enhancedArtwork {
            Task {
                do {
                    // MusicKit Artwork uses url(width:height:) method to get URL, then fetch data
                    if let artworkURL = enhancedArtwork.url(width: 90, height: 90) {
                        let (data, _) = try await URLSession.shared.data(from: artworkURL)
                        if let artworkImage = UIImage(data: data) {
                            self.currentImage = artworkImage
                            logger.log("Loaded MusicKit artwork for now playing: '\(song.title)'", level: .debug)
                            return
                        }
                    }
                } catch {
                    logger.log("Failed to load MusicKit artwork for now playing: \(error.localizedDescription)", level: .debug)
                    // Fall through to MediaPlayer artwork
                }
            }
        }
        
        // Fallback to MediaPlayer artwork
        if let artwork = song.artwork {
            Task {
                let image = await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let artworkImage = artwork.image(at: CGSize(width: 90, height: 90))
                        continuation.resume(returning: artworkImage)
                    }
                }
                self.currentImage = image
                logger.log("Loaded MediaPlayer artwork for now playing: '\(song.title)'", level: .debug)
            }
        } else if !isCurrentSongFromLibrary {
            // For non-library songs with no artwork, we should show a placeholder
            // and mark this as needing urgent enhancement
            logger.log("Non-library song '\(song.title)' has no artwork - placeholder shown, enhancement needed", level: .info)
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
