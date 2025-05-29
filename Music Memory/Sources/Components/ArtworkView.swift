import SwiftUI
import MediaPlayer

struct ArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let size: CGFloat
    let isCurrentlyPlaying: Bool
    let isActivelyPlaying: Bool
    @State private var image: UIImage?
    @State private var animationOffset: CGFloat = 0
    
    init(artwork: MPMediaItemArtwork?, size: CGFloat, isCurrentlyPlaying: Bool = false, isActivelyPlaying: Bool = false) {
        self.artwork = artwork
        self.size = size
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
    }
    
    // Convenience initializer for Song objects
    init(song: Song, size: CGFloat, isCurrentlyPlaying: Bool = false, isActivelyPlaying: Bool = false) {
        self.artwork = song.artwork
        self.size = size
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
    }
    
    var body: some View {
        ZStack {
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
            
            if isCurrentlyPlaying {
                // Semi-transparent overlay
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: size, height: size)
                
                if isActivelyPlaying {
                    // Animated equalizer bars for actively playing
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 3, height: getBarHeight(for: index))
                                .animation(
                                    .easeInOut(duration: 0.25 + Double(index) * 0.1)
                                    .repeatForever(autoreverses: true),
                                    value: animationOffset
                                )
                        }
                    }
                } else {
                    // Static pause icon for paused state
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white)
                }
            }
        }
        .onAppear {
            loadArtwork()
            if isActivelyPlaying {
                startAnimation()
            }
        }
        .onChange(of: isActivelyPlaying) { oldValue, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func loadArtwork() {
        // Use MediaPlayer artwork - MusicKit enhancement ready for future implementation
        if let artwork = artwork {
            image = artwork.image(at: CGSize(width: size, height: size))
        }
    }
    
    private func startAnimation() {
        withAnimation {
            animationOffset = 1.0
        }
    }
    
    private func getBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        let animationFactor = sin(animationOffset * .pi + Double(index) * 0.8)
        return baseHeight + (maxHeight - baseHeight) * max(0, animationFactor)
    }
}

// MARK: - Artwork Detail View for Song Detail Screen

struct ArtworkDetailView: View {
    let artwork: UIImage?
    let isCurrentlyPlaying: Bool
    let isActivelyPlaying: Bool
    @State private var displayImage: UIImage?
    @State private var animationOffset: CGFloat = 0
    
    init(artwork: UIImage?, isCurrentlyPlaying: Bool, isActivelyPlaying: Bool) {
        self.artwork = artwork
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
    }
    
    var body: some View {
        ZStack {
            Group {
                if let image = displayImage {
                    Image(uiImage: image)
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
            
            if isCurrentlyPlaying {
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(Color.black.opacity(0.6))
                    .frame(maxWidth: 300, maxHeight: 300)
                
                if isActivelyPlaying {
                    // Animated equalizer bars for actively playing
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 6, height: getBarHeight(for: index))
                                .animation(
                                    .easeInOut(duration: 0.3 + Double(index) * 0.1)
                                    .repeatForever(autoreverses: true),
                                    value: animationOffset
                                )
                        }
                    }
                } else {
                    // Static pause icon for paused state
                    Image(systemName: "pause.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.white)
                }
            }
        }
        .onAppear {
            loadDetailArtwork()
            if isActivelyPlaying {
                startAnimation()
            }
        }
        .onChange(of: isActivelyPlaying) { oldValue, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func loadDetailArtwork() {
        // Use provided artwork - MusicKit enhancement ready for future implementation
        if let artwork = artwork {
            displayImage = artwork
        }
    }
    
    private func startAnimation() {
        withAnimation {
            animationOffset = 1.0
        }
    }
    
    private func getBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 16
        let maxHeight: CGFloat = 40
        let animationFactor = sin(animationOffset * .pi + Double(index) * 0.8)
        return baseHeight + (maxHeight - baseHeight) * max(0, animationFactor)
    }
}
