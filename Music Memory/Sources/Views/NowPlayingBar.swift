import SwiftUI
import MediaPlayer
import Combine

struct NowPlayingBar: View {
    @ObservedObject private var viewModel = NowPlayingViewModel.shared
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var currentImage: UIImage?
    
    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.small) {
                    // Artwork with direct image state
                    if let image = currentImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(AppRadius.small)
                    } else {
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(12)
                            .foregroundColor(AppColors.secondaryText)
                            .frame(width: 50, height: 50)
                            .background(AppColors.secondaryBackground)
                            .cornerRadius(AppRadius.small)
                    }
                    
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
            .onChange(of: viewModel.currentArtwork) { artwork in
                updateArtwork(artwork)
            }
            .onAppear {
                updateArtwork(viewModel.currentArtwork)
            }
        }
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
    
    // Track previous playback state and current song ID
    private var previousPlaybackState: MPMusicPlaybackState?
    private var currentSongID: String?
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
                
                // Debug print for testing media library refresh
                if let mediaItem = self?.musicPlayer.nowPlayingItem {
                    print("Now playing item changed - refreshing media library")
                    print("  Title: \(mediaItem.title ?? "Unknown Title")")
                    print("  Artist: \(mediaItem.artist ?? "Unknown Artist")")
                    print("  Album: \(mediaItem.albumTitle ?? "Unknown Album")")
                    print("  Play Count: \(mediaItem.playCount)")
                    print("  Has Artwork: \(mediaItem.artwork != nil ? "Yes" : "No")")
                    print("  Persistent ID: \(mediaItem.persistentID.stringValue)")
                } else {
                    print("Now playing item changed - No item playing")
                }
                
                // Post a notification for library refresh
                NotificationCenter.default.post(name: .nowPlayingItemChanged, object: nil)
            }
            .store(in: &cancellables)
            
        // Observe playback completion notification
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange, object: musicPlayer)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkForSongCompletion()
            }
            .store(in: &cancellables)
    }
    
    func checkCurrentlyPlaying() {
        updatePlaybackState()
        updateNowPlayingItem()
    }
    
    func updatePlaybackState() {
        let newState = musicPlayer.playbackState
        isPlaying = newState == .playing
        previousPlaybackState = newState
    }
    
    func checkForSongCompletion() {
        let currentState = musicPlayer.playbackState
        
        // Check if song is the same but state changed from playing to stopped/paused
        if previousPlaybackState == .playing &&
           (currentState == .stopped || currentState == .paused) {
            // The song likely completed playing
            logger.log("Song completed - refreshing media library", level: .info)
            
            // Invalidate the cache to get fresh data
            if let musicLibraryService = DIContainer.shared.musicLibraryService as? MusicLibraryService {
                Task {
                    await musicLibraryService.invalidateCache()
                    // Post notification that others can observe
                    NotificationCenter.default.post(name: .mediaLibraryChanged, object: nil)
                }
            }
        }
        
        // Update the previous state
        previousPlaybackState = currentState
    }
    
    func updateNowPlayingItem() {
        if let mediaItem = musicPlayer.nowPlayingItem {
            let songID = mediaItem.persistentID.stringValue
            title = mediaItem.title ?? "Unknown Title"
            artist = mediaItem.artist ?? "Unknown Artist"
            currentArtwork = mediaItem.artwork
            currentSong = Song(from: mediaItem)
            isVisible = true
            
            // If the same song is playing again (repeated)
            if songID == currentSongID {
                logger.log("Same song playing again - refreshing media library", level: .info)
                
                // Invalidate the cache to ensure fresh play count data
                if let musicLibraryService = DIContainer.shared.musicLibraryService as? MusicLibraryService {
                    Task {
                        await musicLibraryService.invalidateCache()
                        // Post notification that others can observe
                        NotificationCenter.default.post(name: .mediaLibraryChanged, object: nil)
                    }
                }
            }
            
            // Update current song ID
            currentSongID = songID
        } else {
            isVisible = false
            currentSong = nil
            currentArtwork = nil
            currentSongID = nil
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
