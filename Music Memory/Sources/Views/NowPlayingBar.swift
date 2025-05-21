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
                Button {
                    // Navigate to song detail view when the now playing bar is tapped
                    if let currentSong = viewModel.currentSong {
                        navigationManager.navigateToSongDetail(song: currentSong)
                    }
                } label: {
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
                        
                        // Rank number - matching style from SongRowView
                        Text("\(viewModel.songRank ?? 0)")
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.primary)
                            .frame(width: 50, alignment: .center)
                        
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
                }
                .buttonStyle(PlainButtonStyle()) // Use plain style to avoid visual changes
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.medium)
                .background(AppColors.secondaryBackground)
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
}

// Extend NSNotification.Name for song rank updates
extension NSNotification.Name {
    static let requestSongRankUpdate = NSNotification.Name("requestSongRankUpdate")
    static let songsListUpdated = NSNotification.Name("songsListUpdated")
}
