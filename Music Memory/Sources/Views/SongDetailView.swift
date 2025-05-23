import SwiftUI
import UIKit
import MediaPlayer

struct SongDetailView: View {
    @ObservedObject var viewModel: SongDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var navigationManager: NavigationManager
    @ObservedObject private var nowPlayingViewModel = NowPlayingViewModel.shared
    
    // Check if this song is currently playing
    private var isCurrentlyPlaying: Bool {
        nowPlayingViewModel.currentSong?.id == viewModel.song.id
    }
    
    // Check if this song is the current song and actively playing (not paused)
    private var isActivelyPlaying: Bool {
        isCurrentlyPlaying && nowPlayingViewModel.isPlaying
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                // Artwork section - now clickable to play/pause
                Button(action: {
                    AppHaptics.mediumImpact()
                    if isCurrentlyPlaying {
                        // If this song is currently playing, pause it
                        nowPlayingViewModel.togglePlayback()
                    } else {
                        // If this song is not playing, play it
                        playSingleSong(viewModel.song)
                    }
                }) {
                    ArtworkDetailView(
                        artwork: viewModel.artwork,
                        isCurrentlyPlaying: isCurrentlyPlaying,
                        isActivelyPlaying: isActivelyPlaying
                    )
                }
                .buttonStyle(.plain)
                
                // Primary song information
                VStack(spacing: AppSpacing.small) {
                    TitleText(text: viewModel.song.title, weight: AppFontWeight.bold)
                        .multilineTextAlignment(.center)

                    SubheadlineText(text: viewModel.song.artist)
                    SubheadlineText(text: viewModel.song.album)
                    
                    // Play count highlight - using displayedPlayCount
                    HStack {
                        Spacer()
                        VStack {
                            Text("\(viewModel.song.displayedPlayCount)")
                                .font(.system(size: AppFontSize.huge, weight: .bold))
                                .foregroundColor(AppColors.primary)
                            
                            Text("Plays")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.top, AppSpacing.large)
                    
                    // Removed the separate play button - now handled by artwork tap
                }
                
                Divider()
                    .padding(.top, AppSpacing.small)
                
                // Detailed information sections
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    // Playback Statistics Section
                    DetailSectionView(title: "Playback Statistics") {
                        DetailRowView(label: "Play Count", value: "\(viewModel.song.displayedPlayCount)")
                        DetailRowView(label: "Skip Count", value: "\(viewModel.skipCount)")
                        if viewModel.lastPlayedDate != "Never" {
                            DetailRowView(label: "Last Played", value: viewModel.lastPlayedDate)
                        }
                        if viewModel.rating > 0 {
                            DetailRowView(label: "Rating", value: String(repeating: "★", count: viewModel.rating))
                        }
                    }
                    
                    // Track Information Section
                    DetailSectionView(title: "Track Information") {
                        DetailRowView(label: "Duration", value: viewModel.duration)
                        if viewModel.genre != "Unknown" {
                            DetailRowView(label: "Genre", value: viewModel.genre)
                        }
                        if viewModel.trackNumber != "Unknown" {
                            DetailRowView(label: "Track Number", value: viewModel.trackNumber)
                        }
                        if viewModel.discNumber != "Unknown" {
                            DetailRowView(label: "Disc Number", value: viewModel.discNumber)
                        }
                        if viewModel.bpm > 0 {
                            DetailRowView(label: "BPM", value: "\(viewModel.bpm)")
                        }
                    }
                    
                    // Creator Information Section
                    if viewModel.composer != "Unknown" {
                        DetailSectionView(title: "Creator Information") {
                            DetailRowView(label: "Composer", value: viewModel.composer)
                        }
                    }
                    
                    // Release Information Section
                    DetailSectionView(title: "Release Information") {
                        DetailRowView(label: "Album", value: viewModel.song.album)
                        if viewModel.releaseDate != "Unknown" {
                            DetailRowView(label: "Release Date", value: viewModel.releaseDate)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .standardPadding()
            .padding(.bottom, 90) // Add bottom padding to account for the Now Playing bar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Share functionality could be implemented here
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func playSingleSong(_ song: Song) {
        // Play only this single song (no queue) when played from detail view
        NowPlayingViewModel.shared.playSong(song, fromQueue: nil)
    }
}

// Detail Section View
struct DetailSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HeadlineText(text: title)
                .fontWeight(AppFontWeight.semibold)
                .padding(.bottom, AppSpacing.tiny)
            
            content
            
            Divider()
                .padding(.top, AppSpacing.small)
        }
    }
}

// Detail Row View
struct DetailRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.tiny)
    }
}

struct ArtworkDetailView: View {
    let artwork: UIImage?
    let isCurrentlyPlaying: Bool
    let isActivelyPlaying: Bool
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base artwork
            Group {
                if let artwork = artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(AppRadius.large)
                        .appShadow(AppShadow.medium)
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(AppSpacing.huge)
                        .foregroundColor(AppColors.secondaryText)
                        .background(AppColors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                        .appShadow(AppShadow.medium)
                }
            }
            .frame(maxWidth: 300, maxHeight: 300)
            
            // Overlay for currently playing song
            if isCurrentlyPlaying {
                // Semi-transparent overlay
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(Color.black.opacity(0.6))
                    .frame(maxWidth: 300, maxHeight: 300)
                
                if isActivelyPlaying {
                    // Animated equalizer bars for actively playing - FASTER ANIMATION
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 6, height: getBarHeight(for: index))
                                .animation(
                                    .easeInOut(duration: 0.3 + Double(index) * 0.1) // Reduced from 0.5 + 0.2 to 0.3 + 0.1
                                    .repeatForever(autoreverses: true),
                                    value: animationOffset
                                )
                        }
                    }
                } else {
                    // Static pause icon for paused state
                    Image(systemName: "pause.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.white)
                }
            }
        }
        .onAppear {
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
    
    private func startAnimation() {
        withAnimation {
            animationOffset = 1.0
        }
    }
    
    private func getBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 16
        let maxHeight: CGFloat = 40
        let animationFactor = sin(animationOffset * .pi + Double(index) * 0.8)
        return baseHeight + (maxHeight - baseHeight) * max(0, animationFactor)
    }
}

// Preview extension
extension SongDetailView {
    static func preview() -> some View {
        let mockSong = PreviewSongFactory.mockSongs.first!
        let viewModel = SongDetailViewModel.preview(song: mockSong)
        
        return NavigationStack {
            SongDetailView(viewModel: viewModel)
        }
        .previewWithContainer(DIContainer.preview())
        .environmentObject(NavigationManager())
    }
}
