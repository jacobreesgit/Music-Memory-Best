import SwiftUI
import MediaPlayer
import Combine

struct SongListView: View {
    @ObservedObject var viewModel: SongListViewModel
    
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
    private var cancellable: Cancellable?
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(artwork: song.artwork, size: 50)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(song.album)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            PlayCountView(count: song.playCount)
        }
        .padding(.vertical, 4)
    }
}

struct PlayCountView: View {
    let count: Int
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .foregroundColor(count > 0 ? .primary : .secondary)
            
            Text("plays")
                .font(.caption2)
                .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.systemGray6))
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
        let mockSongs = ContentView_Previews.createMockSongs()
        let container = DIContainer.preview(withMockSongs: mockSongs)
        let viewModel = SongListViewModel(
            musicLibraryService: container.musicLibraryService,
            logger: container.logger
        )
        viewModel.songs = mockSongs
        
        return SongListView(viewModel: viewModel)
            .previewWithContainer(container)
    }
}
