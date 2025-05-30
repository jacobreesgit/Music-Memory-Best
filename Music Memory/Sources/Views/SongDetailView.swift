import SwiftUI
import UIKit
import MediaPlayer

struct SongDetailView: View {
    @ObservedObject var viewModel: SongDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var navigationManager: NavigationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                // Enhanced artwork view with MusicKit support and progressive loading
                ArtworkDetailView(
                    song: viewModel.song,
                    isCurrentlyPlaying: false,
                    isActivelyPlaying: false
                )
                
                // Primary song information
                VStack(spacing: AppSpacing.small) {
                    // Song title - removed sparkles indicator
                    TitleText(text: viewModel.song.title, weight: AppFontWeight.bold)
                        .multilineTextAlignment(.center)

                    SubheadlineText(text: viewModel.song.enhancedArtist)
                    SubheadlineText(text: viewModel.song.enhancedAlbum)
                    
                    // Explicit content indicator (only show if explicit)
                    if viewModel.isExplicit {
                        HStack {
                            Image(systemName: "e.square.fill")
                                .foregroundColor(AppColors.secondaryText)
                            Text("Explicit")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
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
                        if viewModel.isExplicit {
                            DetailRowView(label: "Content Rating", value: "Explicit")
                        }
                    }
                    
                    // Creator Information Section
                    if viewModel.composer != "Unknown" {
                        DetailSectionView(title: "Creator Information") {
                            DetailRowView(label: "Artist", value: viewModel.song.enhancedArtist)
                            DetailRowView(label: "Composer", value: viewModel.composer)
                        }
                    }
                    
                    // Release Information Section
                    DetailSectionView(title: "Release Information") {
                        DetailRowView(label: "Album", value: viewModel.song.enhancedAlbum)
                        if viewModel.releaseDate != "Unknown" {
                            DetailRowView(label: "Release Date", value: viewModel.releaseDate)
                        }
                    }
                    
                    // File Information Section
                    if viewModel.fileSize != "Unknown" {
                        DetailSectionView(title: "File Information") {
                            DetailRowView(label: "File Size", value: viewModel.fileSize)
                        }
                    }
                    
                    // Enhancement Status Section
                    DetailSectionView(title: "Enhancement Status") {
                        DetailRowView(label: "Status", value: viewModel.enhancementStatus)
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
