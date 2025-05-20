import SwiftUI
import MediaPlayer
import Combine

struct SongListView: View {
    @ObservedObject var viewModel: SongListViewModel
    @Environment(\.isPreview) private var isPreview
    
    var body: some View {
        List {
            ForEach(viewModel.songs) { song in
                NavigationLink(
                    destination: SongDetailView(
                        viewModel: SongDetailViewModel(
                            song: song,
                            logger: DIContainer.shared.logger
                        )
                    )
                ) {
                    SongRowView(song: song)
                }
            }
        }
        .refreshable {
            await viewModel.loadSongs()
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
}

struct SongRowView: View {
    let song: Song
    @State private var image: UIImage?
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            ArtworkView(artwork: song.artwork, size: 50)
                .cornerRadius(AppRadius.small)
            
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                HeadlineText(text: song.title)
                    .lineLimit(1)

                SubheadlineText(text: song.artist)
                    .lineLimit(1)

                CaptionText(text: song.album)
                    .lineLimit(1)
            }
            
            Spacer()
            
            PlayCountView(count: song.playCount)
        }
        .padding(.vertical, AppSpacing.tiny)
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
    }
}
