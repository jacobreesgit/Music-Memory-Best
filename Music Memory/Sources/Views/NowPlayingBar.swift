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
    
    /*
     Haptic Feedback Patterns used in this view:
     - AppHaptics.success(): When successfully navigating to song detail
     - AppHaptics.error(): When blocked from navigating (already on that song's detail)
     - AppHaptics.mediumImpact(): Play/pause button and long press begin
     - AppHaptics.lightImpact(): Previous/next buttons and blocked press feedback
     */
    
    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
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
                    
                    // Rank number - ensuring exact match with SongRowView
                    Text("\(viewModel.songRank ?? 0)")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primary)
                        .frame(width: 50, alignment: .center)
                    
                    // Song info - Using design system text components
                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                        HeadlineText(text: viewModel.title)
                            .lineLimit(1)
                        
                        SubheadlineText(text: viewModel.artist)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Playback control buttons
                    HStack(spacing: 0) {
                        // Previous button
                        Button(action: {
                            AppHaptics.lightImpact()
                            viewModel.skipToPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.primaryText) // Changed from AppColors.black to AppColors.primaryText
                                .frame(width: 36, height: 36)
                        }
                        
                        // Play/Pause button
                        Button(action: {
                            AppHaptics.mediumImpact()
                            viewModel.togglePlayback()
                        }) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.primaryText) // Changed from AppColors.black to AppColors.primaryText
                                .frame(width: 44, height: 44)
                        }
                        
                        // Next button
                        Button(action: {
                            AppHaptics.lightImpact()
                            viewModel.skipToNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.primaryText) // Changed from AppColors.black to AppColors.primaryText
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
    @Published var songRank: Int? = nil // Added to track rank of the currently playing song
    
    private var logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
        checkCurrentlyPlaying()
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }
    
    func setupObservers() {
        // Begin generating notifications
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        // Observe playback state changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange, object: musicPlayer)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
        
        // Observe now playing item changes
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange, object: musicPlayer)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateNowPlayingItem()
            }
            .store(in: &cancellables)
        
        // Listen for media library changes from the central notification
        NotificationCenter.default.publisher(for: .mediaLibraryChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Update the current song info when library changes
                self?.updateNowPlayingItem()
            }
            .store(in: &cancellables)
            
        // Listen for song list updates to update rank
        NotificationCenter.default.publisher(for: .songsListUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let songs = notification.object as? [Song] {
                    self?.updateSongRank(songs: songs)
                }
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
    
    func updateNowPlayingItem() {
        if let mediaItem = musicPlayer.nowPlayingItem {
            title = mediaItem.title ?? "Unknown Title"
            artist = mediaItem.artist ?? "Unknown Artist"
            currentArtwork = mediaItem.artwork
            currentSong = Song(from: mediaItem)
            isVisible = true
            
            // Request to update rank based on newest song list
            NotificationCenter.default.post(name: .requestSongRankUpdate, object: currentSong)
        } else {
            isVisible = false
            currentSong = nil
            currentArtwork = nil
            songRank = nil
        }
    }
    
    func updateSongRank(songs: [Song]) {
        guard let currentSong = currentSong else {
            songRank = nil
            return
        }
        
        // Find the index of the current song in the song list (sorted by play count)
        if let index = songs.firstIndex(where: { $0.id == currentSong.id }) {
            songRank = index + 1
        } else {
            songRank = nil
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
    
    // MARK: - New playback control methods
    
    func skipToNext() {
        logger.log("Skipping to next track", level: .info)
        musicPlayer.skipToNextItem()
    }
    
    func skipToPrevious() {
        logger.log("Skipping to previous track", level: .info)
        musicPlayer.skipToPreviousItem()
    }
}

// Extend NSNotification.Name for song rank updates
extension NSNotification.Name {
    static let requestSongRankUpdate = NSNotification.Name("requestSongRankUpdate")
    static let songsListUpdated = NSNotification.Name("songsListUpdated")
}
