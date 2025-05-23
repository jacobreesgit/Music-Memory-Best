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
    
    // Check if this song is the current song and actively playing (not paused)
    private var isActivelyPlaying: Bool {
        isCurrentlyPlaying && nowPlayingViewModel.isPlaying
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            // Play button area (artwork only) - clicking here plays the song
            Button(action: onPlay) {
                ArtworkView(
                    artwork: song.artwork,
                    size: 45,
                    isCurrentlyPlaying: isCurrentlyPlaying,
                    isActivelyPlaying: isActivelyPlaying
                )
                .cornerRadius(AppRadius.small)
            }
            .buttonStyle(.plain)
            
            // Navigation area (everything else) - clicking anywhere here goes to detail view
            HStack(spacing: AppSpacing.small) {
                Text("\(index + 1)")
                    .font(AppFonts.callout)
                    .fontWeight(AppFontWeight.semibold)
                    .foregroundColor(AppColors.primary)
                    .frame(width: (index + 1) >= 1000 ? 47 : 37, alignment: .center)
                
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    // Use smaller, sleeker fonts matching now playing bar
                    Text(song.title)
                        .font(AppFonts.callout)
                        .fontWeight(isCurrentlyPlaying ? AppFontWeight.semibold : AppFontWeight.regular)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Use displayedPlayCount instead of playCount
                PlayCountView(count: song.displayedPlayCount)
            }
            .contentShape(Rectangle()) // Make the entire area including spacer tappable
            .onTapGesture {
                onNavigate()
            }
        }
        .padding(.vertical, 0) // Removed all vertical padding from the row
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
                        playSongFromQueue(song, queue: viewModel.songs)
                    },
                    onNavigate: {
                        // Provide success haptic feedback for successful navigation
                        AppHaptics.success()
                        navigationManager.navigateToSongDetail(song: song)
                    }
                )
                .listRowInsets(EdgeInsets(top: AppSpacing.small, leading: 16, bottom: AppSpacing.small, trailing: 16))
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
    
    private func playSongFromQueue(_ song: Song, queue: [Song]) {
        // Play the selected song with the full queue for continuous playback
        NowPlayingViewModel.shared.playSong(song, fromQueue: queue)
    }
}

struct PlayCountView: View {
    let count: Int
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(AppFonts.callout)
                .fontWeight(AppFontWeight.medium)
                .foregroundColor(count > 0 ? AppColors.primaryText : AppColors.secondaryText)
            
            Text("plays")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

struct ArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let size: CGFloat
    let isCurrentlyPlaying: Bool
    let isActivelyPlaying: Bool
    @State private var image: UIImage?
    @State private var animationOffset: CGFloat = 0
    
    init(artwork: MPMediaItemArtwork?, size: CGFloat, isCurrentlyPlaying: Bool = false, isActivelyPlaying: Bool = false) {
        self.artwork = artwork
        self.size = size
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
    }
    
    var body: some View {
        ZStack {
            // Base artwork
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
            
            // Overlay for currently selected song
            if isCurrentlyPlaying {
                // Semi-transparent overlay
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: size, height: size)
                
                if isActivelyPlaying {
                    // Animated equalizer bars for actively playing
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 3, height: getBarHeight(for: index))
                                .animation(
                                    .easeInOut(duration: 0.5 + Double(index) * 0.2)
                                    .repeatForever(autoreverses: true),
                                    value: animationOffset
                                )
                        }
                    }
                } else {
                    // Static pause icon for paused state
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white)
                }
            }
        }
        .onAppear {
            loadArtwork()
            if isActivelyPlaying {
                startAnimation()
            }
        }
        .onChange(of: isActivelyPlaying) { oldValue, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func loadArtwork() {
        if let artwork = artwork {
            image = artwork.image(at: CGSize(width: size, height: size))
        }
    }
    
    private func startAnimation() {
        withAnimation {
            animationOffset = 1.0
        }
    }
    
    private func getBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        let animationFactor = sin(animationOffset * .pi + Double(index) * 0.8)
        return baseHeight + (maxHeight - baseHeight) * max(0, animationFactor)
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
