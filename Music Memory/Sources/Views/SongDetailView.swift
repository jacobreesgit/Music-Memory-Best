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
                ArtworkDetailView(artwork: viewModel.artwork)
                
                VStack(spacing: AppSpacing.small) {
                    TitleText(text: viewModel.song.title, weight: AppFontWeight.bold)
                        .multilineTextAlignment(.center)

                    // For artist, we could use a slightly modified SubheadlineText
                    SubheadlineText(text: viewModel.song.artist)

                    SubheadlineText(text: viewModel.song.album)
                    
                    // Play count in detail view
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
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(AppRadius.medium)
                    }
                    .padding(.top, AppSpacing.medium)
                }
            }
            .standardPadding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Button action could be to share song or other functionality
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
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
