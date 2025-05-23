import SwiftUI
import MediaPlayer
import Combine

struct SongRowView: View {
    let song: Song
    let index: Int
    let onPlay: () -> Void
    let onNavigate: () -> Void
    @State private var image: UIImage?
    @ObservedObject private var nowPlayingViewModel = NowPlayingViewModel.shared
    
    // Check if this song is currently playing
    private var isCurrentlyPlaying: Bool {
        nowPlayingViewModel.currentSong?.id == song.id
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            // Play button area (artwork) - clicking here plays the song
            Button(action: onPlay) {
                ArtworkView(artwork: song.artwork, size: 50)
                    .cornerRadius(AppRadius.small)
            }
            .buttonStyle(.plain)
            
            // Navigation area (rest of the row) - clicking here goes to detail view
            Button(action: onNavigate) {
                HStack(spacing: AppSpacing.small) {
                    Text("\(index + 1)")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primary)
                        .frame(width: 50, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                        // Use HeadlineText for currently playing song, BodyText for others
                        if isCurrentlyPlaying {
                            HeadlineText(text: song.title)
                                .lineLimit(1)
                        } else {
                            BodyText(text: song.title)
                                .lineLimit(1)
                        }

                        SubheadlineText(text: song.artist)
                            .lineLimit(1)
                        
                    }
                    
                    Spacer()
                    
                    PlayCountView(count: song.playCount)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, AppSpacing.tiny)
    }
}

struct SongListView: View {
    @ObservedObject var viewModel: SongListViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.isPreview) private var isPreview
    
    var body: some View {
        List {
            ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                SongRowView(
                    song: song,
                    index: index,
                    onPlay: {
                        // Provide medium impact haptic feedback for playing song (important action)
                        AppHaptics.mediumImpact()
                        playSong(song)
                    },
                    onNavigate: {
                        // Provide success haptic feedback for successful navigation
                        AppHaptics.success()
                        navigationManager.navigateToSongDetail(song: song)
                    }
                )
            }
        }
        .overlay(
            Group {
                if viewModel.songs.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Songs Found",
                        systemImage: "music.note",
                        description: Text("Your music library appears to be empty.")
                    )
                }
            }
        )
    }
    
    private func playSong(_ song: Song) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        let descriptor = MPMediaItemCollection(items: [song.mediaItem])
        musicPlayer.setQueue(with: descriptor)
        musicPlayer.prepareToPlay()
        musicPlayer.play()
    }
}

struct PlayCountView: View {
    let count: Int
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(AppFonts.headline)
                .foregroundColor(count > 0 ? AppColors.primaryText : AppColors.secondaryText)
            
            CaptionText(text: "plays")
        }
    }
}

struct ArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let size: CGFloat
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size / 4)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .background(AppColors.secondaryBackground)
        .onAppear {
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        if let artwork = artwork {
            image = artwork.image(at: CGSize(width: size, height: size))
        }
    }
}

// Preview extension
extension SongListView {
    static func preview() -> some View {
        let mockSongs = PreviewSongFactory.mockSongs
        let viewModel = SongListViewModel.preview(withSongs: mockSongs)
        
        return SongListView(viewModel: viewModel)
            .previewWithContainer(DIContainer.preview(withMockSongs: mockSongs))
            .environmentObject(NavigationManager())
    }
}
