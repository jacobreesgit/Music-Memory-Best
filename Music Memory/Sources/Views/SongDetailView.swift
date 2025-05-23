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
                // Artwork section
                ArtworkDetailView(artwork: viewModel.artwork)
                
                // Primary song information
                VStack(spacing: AppSpacing.small) {
                    TitleText(text: viewModel.song.title, weight: AppFontWeight.bold)
                        .multilineTextAlignment(.center)

                    SubheadlineText(text: viewModel.song.artist)
                    SubheadlineText(text: viewModel.song.album)
                    
                    // Play count highlight
                    HStack {
                        Spacer()
                        VStack {
                            Text("\(viewModel.song.playCount)")
                                .font(.system(size: AppFontSize.huge, weight: .bold))
                                .foregroundColor(AppColors.primary)
                            
                            Text("Plays")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.top, AppSpacing.large)
                    
                    // Play button
                    Button(action: {
                        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
                        let descriptor = MPMediaItemCollection(items: [viewModel.song.mediaItem])
                        musicPlayer.setQueue(with: descriptor)
                        musicPlayer.prepareToPlay()
                        musicPlayer.play()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                    }
                    .primaryStyle()
                    .padding(.top, AppSpacing.medium)
                }
                
                Divider()
                    .padding(.top, AppSpacing.small)
                
                // Detailed information sections
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    // Playback Statistics Section
                    DetailSectionView(title: "Playback Statistics") {
                        DetailRowView(label: "Play Count", value: "\(viewModel.song.playCount)")
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
                    
                    // File Information section has been removed as requested
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
    
    var body: some View {
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
