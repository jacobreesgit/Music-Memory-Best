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
                    TitleText(text: viewModel.song.title, weight: AppFontWeight.bold)
                        .multilineTextAlignment(.center)

                    // For artist, we could use a slightly modified SubheadlineText
                    SubheadlineText(text: viewModel.song.artist)

                    SubheadlineText(text: viewModel.song.album)
                }
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

// Preview extension
extension SongDetailView {
    static func preview() -> some View {
        let mockSong = PreviewSongFactory.mockSongs.first!
        let viewModel = SongDetailViewModel.preview(song: mockSong)
        
        return SongDetailView(viewModel: viewModel)
            .previewWithContainer(DIContainer.preview())
    }
}
