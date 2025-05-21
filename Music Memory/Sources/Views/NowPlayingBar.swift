import SwiftUI
import MediaPlayer
import Combine

struct NowPlayingBar: View {
    @ObservedObject private var viewModel = NowPlayingViewModel.shared
    @EnvironmentObject var navigationManager: NavigationManager
    
    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.small) {
                    // Artwork
                    ArtworkView(artwork: viewModel.currentArtwork, size: 50)
                        .cornerRadius(AppRadius.small)
                    
                    // Song info
                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                        Text(viewModel.title)
                            .font(AppFonts.headline)
                            .lineLimit(1)
                        
                        Text(viewModel.artist)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button(action: {
                        viewModel.togglePlayback()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.medium)
                .background(AppColors.secondaryBackground)
                .cornerRadius(AppRadius.medium)
                .appShadow(AppShadow.medium)
                .padding(.horizontal, AppSpacing.medium)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: viewModel.isVisible)
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
                
                // Debug print for testing media library refresh
                print("Now playing item changed - refreshing media library")
                
                // Post a notification for library refresh
                NotificationCenter.default.post(name: .nowPlayingItemChanged, object: nil)
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
        } else {
            isVisible = false
            currentSong = nil
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
}

// Notification name extension
extension NSNotification.Name {
    static let nowPlayingItemChanged = NSNotification.Name("nowPlayingItemChanged")
}
