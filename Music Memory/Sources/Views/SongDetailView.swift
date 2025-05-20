import SwiftUI
import UIKit

struct SongDetailView: View {
    @ObservedObject var viewModel: SongDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                ArtworkDetailView(artwork: viewModel.artwork)
                
                VStack(spacing: AppSpacing.small) {
                    Text(viewModel.song.title)
                        .font(AppFonts.title)
                        .fontWeight(AppFontWeight.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(viewModel.song.artist)
                        .font(AppFonts.title3)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text(viewModel.song.album)
                        .font(AppFonts.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
                .horizontalPadding()
                
                PlayDetailView(playCount: viewModel.song.playCount)
            }
            .standardPadding()
        }
        .navigationBarTitleDisplayMode(.inline)
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

struct PlayDetailView: View {
    let playCount: Int
    
    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Text("Play Count")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.secondaryText)
            
            Text("\(playCount)")
                .font(AppFonts.system(size: AppFontSize.huge, weight: AppFontWeight.bold))
                .foregroundStyle(playCount > 0 ? AppColors.primaryText : AppColors.secondaryText)
                .frame(height: 56)
            
            Text(playCount == 1 ? "time" : "times")
                .font(AppFonts.subheadline)
                .foregroundColor(AppColors.secondaryText)
        }
        .standardPadding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.background)
                .appShadow(AppShadow.small)
        )
    }
}

// Preview extension
extension SongDetailView {
    static func preview() -> some View {
        let mockSong = PreviewSongFactory.mockSongs.first!
        let viewModel = SongDetailViewModel.preview(song: mockSong)
        
        return SongDetailView(viewModel: viewModel)
            .previewWithContainer(DIContainer.preview())
    }
}
