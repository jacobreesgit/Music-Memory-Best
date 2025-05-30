import SwiftUI
import MediaPlayer
import Combine

struct SongRowView: View {
    let song: Song
    let index: Int
    let rankChange: RankChange?
    let onPlay: () -> Void
    let onNavigate: () -> Void
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
            // Play/Pause button area (artwork only) - clicking here plays or pauses the song
            Button(action: {
                if isCurrentlyPlaying {
                    // If this song is currently playing, pause it
                    AppHaptics.mediumImpact()
                    NowPlayingViewModel.shared.togglePlayback()
                } else {
                    // If this song is not playing, play it
                    onPlay()
                }
            }) {
                ArtworkView(
                    song: song,
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
                    // Song title with MusicKit enhancement if available
                    HStack(spacing: AppSpacing.tiny) {
                        Text(song.title)
                            .font(AppFonts.callout)
                            .fontWeight(isCurrentlyPlaying ? AppFontWeight.semibold : AppFontWeight.regular)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        // Show MusicKit enhancement indicator if available
                        if song.hasEnhancedData {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.primary.opacity(0.7))
                        }
                    }

                    // Artist name (use enhanced artist name)
                    HStack(spacing: AppSpacing.tiny) {
                        Text(song.enhancedArtist)
                            .font(AppFonts.detail)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                        
                        // Show explicit indicator for explicit content
                        if song.isExplicit {
                            Image(systemName: "e.square.fill")
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.secondaryText.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: AppSpacing.small) {
                    PlayCountView(count: song.displayedPlayCount)
                    
                    if let rankChange = rankChange {
                        HStack(spacing: 1) {
                            Image(systemName: rankChange.icon)
                                .font(AppFonts.detail)
                                .fontWeight(AppFontWeight.medium)
                                .foregroundColor(rankChange.color)
                            
                            if let magnitude = rankChange.magnitude {
                                Text("\(magnitude)")
                                    .font(AppFonts.detail)
                                    .fontWeight(AppFontWeight.medium)
                                    .foregroundColor(rankChange.color)
                            }
                        }
                        .frame(width: 30, height: 12)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onNavigate()
            }
        }
        .padding(.vertical, 0)
    }
}

struct SongListView: View {
    @ObservedObject var viewModel: SongListViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    
    var body: some View {
        List {
            ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                SongRowView(
                    song: song,
                    index: index,
                    rankChange: viewModel.rankChanges[song.id],
                    onPlay: {
                        AppHaptics.mediumImpact()
                        playSongFromQueue(song, queue: viewModel.songs)
                    },
                    onNavigate: {
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
        .refreshable {
            // Add pull-to-refresh functionality to trigger MusicKit re-enhancement
            Task {
                await viewModel.loadSongs()
            }
        }
        .overlay(alignment: .top) {
            // Show enhancement status when songs are being processed
            if viewModel.isLoading {
                EnhancementStatusView()
                    .padding(.top, AppSpacing.small)
            }
        }
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
                .font(AppFonts.detail)
                .fontWeight(AppFontWeight.semibold)
                .foregroundColor(count > 0 ? AppColors.primaryText : AppColors.secondaryText)
            
            Text("plays")
                .font(AppFonts.detail)
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

// MARK: - Enhancement Status View

struct EnhancementStatusView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(AppColors.primary)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            
            Text("Enhancing with MusicKit...")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.tiny)
        .background(AppColors.primary.opacity(0.1))
        .cornerRadius(AppRadius.small)
        .onAppear {
            isAnimating = true
        }
    }
}
