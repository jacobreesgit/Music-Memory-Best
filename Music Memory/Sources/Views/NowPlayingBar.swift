import SwiftUI
import MediaPlayer
import Combine

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
                    // Left side: Artwork, rank, and song info (with navigation gestures)
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
                                    .padding(50 / 4) // Same as size/4 used in ArtworkView
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .background(AppColors.secondaryBackground) // Explicitly add background
                        .cornerRadius(AppRadius.small)
                        
                        // Rank number - using same styling as song list
                        if let rank = viewModel.currentSongRank {
                            Text("\(rank)")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primary)
                                .frame(width: 50, alignment: .center)
                        }
                        
                        // Song info - Using design system text components
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            HeadlineText(text: viewModel.title)
                                .lineLimit(1)
                            
                            HStack(spacing: AppSpacing.tiny) {
                                SubheadlineText(text: viewModel.artist)
                                    .lineLimit(1)
                                
                                if let currentSong = viewModel.currentSong {
                                    Text("•")
                                        .font(AppFonts.subheadline)
                                        .foregroundColor(AppColors.secondaryText)
                                    
                                    Text("\(currentSong.playCount) plays")
                                        .font(AppFonts.subheadline)
                                        .foregroundColor(AppColors.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    // Apply navigation gestures only to the left portion
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
                        // Add a tap gesture for quick access (optional - can be removed if only long press is desired)
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
                    
                    Spacer()
                    
                    // Right side: Playback control buttons (no navigation gestures) - removed previous button
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
                .padding(.leading, 24) // Specify left padding
                .padding(.trailing, 16) // Specify right padding
                .padding(.vertical, AppSpacing.medium)
                .background(.ultraThinMaterial)
                .cornerRadius(AppRadius.medium)
                .appShadow(AppShadow.medium)
                .padding(.horizontal, AppSpacing.medium)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: viewModel.isVisible)
            .onChange(of: viewModel.currentArtwork) { oldValue, newValue in
                updateArtwork(newValue)
            }
            .onAppear {
                updateArtwork(viewModel.currentArtwork)
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
    
    private func updateArtwork(_ artwork: MPMediaItemArtwork?) {
        if let artwork = artwork {
            currentImage = artwork.image(at: CGSize(width: 50, height: 50))
        } else {
            currentImage = nil
        }
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
    
    // Store the songs list to compute rank
    private var songs: [Song] = []
    
    private var logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
        checkCurrentlyPlaying()
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
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
                self?.updateNowPlayingItem()
            }
            .store(in: &cancellables)
    }
    
    func checkCurrentlyPlaying() {
        updatePlaybackState()
        updateNowPlayingItem()
    }
    
    func updatePlaybackState() {
        isPlaying = musicPlayer.playbackState == .playing
    }
    
    func handlePlaybackStateChange() {
        updatePlaybackState()
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
            
            isVisible = true
        } else {
            isVisible = false
            currentSong = nil
            currentArtwork = nil
            currentSongRank = nil
        }
    }
    
    func togglePlayback() {
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
        } else {
            musicPlayer.play()
        }
    }
    
    func playSong(_ song: Song) {
        // Set the queue with just this song
        let descriptor = MPMediaItemCollection(items: [song.mediaItem])
        musicPlayer.setQueue(with: descriptor)
        musicPlayer.prepareToPlay()
        musicPlayer.play()
    }
    
    func skipToNext() {
        logger.log("Skipping to next track", level: .info)
        musicPlayer.skipToNextItem()
    }
    
    func skipToPrevious() {
        logger.log("Skipping to previous track", level: .info)
        musicPlayer.skipToPreviousItem()
    }
}
