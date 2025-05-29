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
                ArtworkDetailView(
                    artwork: viewModel.artwork,
                    enhancedArtwork: viewModel.song.enhancedArtwork,
                    isCurrentlyPlaying: isCurrentlyPlaying,
                    isActivelyPlaying: isActivelyPlaying
                )
                
                // Primary song information
                VStack(spacing: AppSpacing.small) {
                    HStack {
                        TitleText(text: viewModel.song.title, weight: AppFontWeight.bold)
                            .multilineTextAlignment(.center)
                        
                        // Show MusicKit enhancement indicator
                        if viewModel.song.hasEnhancedData {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(AppColors.primary)
                                .help("Enhanced with MusicKit")
                        }
                    }

                    SubheadlineText(text: viewModel.song.artist)
                    SubheadlineText(text: viewModel.song.album)
                    
                    // Play count highlight
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
                }
                
                Divider()
                    .padding(.top, AppSpacing.small)
                
                // Enhanced information notice if MusicKit data is available
                if viewModel.song.hasEnhancedData {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.primary)
                        
                        Text("Enhanced with high-quality artwork and metadata")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(AppColors.primary.opacity(0.1))
                    .cornerRadius(AppRadius.small)
                }
                
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
                    
                    // Data Source Information Section
                    DetailSectionView(title: "Data Sources") {
                        DetailRowView(label: "Primary Data", value: "Apple Music Library")
                        if viewModel.song.hasEnhancedData {
                            DetailRowView(label: "Enhanced Data", value: "MusicKit")
                            DetailRowView(label: "High-Quality Artwork", value: "Available")
                        } else {
                            DetailRowView(label: "Enhancement Status", value: "Standard Quality")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .standardPadding()
            .padding(.bottom, 90) // Add bottom padding to account for the Now Playing bar
        }
        .navigationBarTitleDisplayMode(.inline)
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
