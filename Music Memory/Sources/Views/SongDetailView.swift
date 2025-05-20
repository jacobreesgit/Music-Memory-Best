import SwiftUI
import UIKit

struct SongDetailView: View {
    @ObservedObject var viewModel: SongDetailViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ArtworkDetailView(artwork: viewModel.artwork)
                
                VStack(spacing: 8) {
                    Text(viewModel.song.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.song.artist)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.song.album)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                PlayDetailView(playCount: viewModel.song.playCount)
            }
            .padding()
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
                    .cornerRadius(12)
                    .shadow(radius: 5)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(40)
                    .foregroundColor(.secondary)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5)
            }
        }
        .frame(maxWidth: 300, maxHeight: 300)
    }
}

struct PlayDetailView: View {
    let playCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Play Count")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("\(playCount)")
                .font(.system(size: 48))
                .fontWeight(.bold)
                .foregroundStyle(playCount > 0 ? .primary : .secondary)
                .frame(height: 56)
            
            Text(playCount == 1 ? "time" : "times")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.systemGray4).opacity(0.3), radius: 5)
        )
    }
}

// Preview extension
extension SongDetailView {
    static func preview() -> some View {
        let mockSong = ContentView_Previews.createMockSongs().first!
        let viewModel = SongDetailViewModel.preview(song: mockSong)
        
        return SongDetailView(viewModel: viewModel)
            .previewWithContainer(DIContainer.preview())
    }
}
