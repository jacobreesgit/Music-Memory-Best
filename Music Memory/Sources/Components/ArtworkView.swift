import SwiftUI
@preconcurrency import MediaPlayer
import MusicKit

struct ArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let enhancedArtwork: Artwork?
    let size: CGFloat
    let isCurrentlyPlaying: Bool
    let isActivelyPlaying: Bool
    let songId: String? // CRITICAL FIX: Add song ID for cache lookup
    
    @State private var image: UIImage?
    @State private var isLoading: Bool = true
    @State private var animationOffset: CGFloat = 0
    
    // CRITICAL FIX: Access to artwork cache service
    private let artworkPersistenceService = DIContainer.shared.artworkPersistenceService
    
    init(artwork: MPMediaItemArtwork?, enhancedArtwork: Artwork? = nil, size: CGFloat, isCurrentlyPlaying: Bool = false, isActivelyPlaying: Bool = false, songId: String? = nil) {
        self.artwork = artwork
        self.enhancedArtwork = enhancedArtwork
        self.size = size
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
        self.songId = songId
    }
    
    // Convenience initializer for Song objects
    init(song: Song, size: CGFloat, isCurrentlyPlaying: Bool = false, isActivelyPlaying: Bool = false) {
        self.artwork = song.artwork
        self.enhancedArtwork = song.enhancedArtwork
        self.size = size
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
        self.songId = song.id // CRITICAL FIX: Use song ID for caching
    }
    
    var body: some View {
        ZStack {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else if isLoading {
                    // Show subtle loading state
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .fill(AppColors.secondaryBackground)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(AppColors.secondaryText)
                        )
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
        .onChange(of: enhancedArtwork) { oldValue, newValue in
            // React to progressive enhancement updates
            if newValue != nil && newValue != oldValue {
                loadArtwork()
            }
        }
    }
    
    private func loadArtwork() {
        Task {
            await loadArtworkAsync()
        }
    }
    
    @MainActor
    private func loadArtworkAsync() {
        isLoading = true
        defer { isLoading = false }
        
        // CRITICAL FIX: Try cached artwork first if we have a song ID
        if let songId = songId,
           let cachedImage = artworkPersistenceService.getCachedArtwork(for: songId) {
            self.image = cachedImage
            return
        }
        
        // Determine the appropriate size with 2x resolution for crisp display
        let targetSize = CGSize(width: size * 2, height: size * 2)
        
        // Try MusicKit artwork (progressive enhancement)
        if let enhancedArtwork = enhancedArtwork {
            do {
                if let artworkURL = enhancedArtwork.url(width: Int(targetSize.width), height: Int(targetSize.height)) {
                    let (data, _) = try await URLSession.shared.data(from: artworkURL)
                    if let artworkImage = UIImage(data: data) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.image = artworkImage
                        }
                        
                        // CRITICAL FIX: Cache the enhanced artwork
                        if let songId = songId {
                            artworkPersistenceService.cacheArtworkForSong(songId, artwork: artworkImage)
                        }
                        return
                    }
                }
            } catch {
                // MusicKit artwork failed, fall back to MediaPlayer
                print("MusicKit artwork loading failed: \(error.localizedDescription)")
            }
        }
        
        // Fallback to MediaPlayer artwork (immediate display)
        if let artwork = artwork {
            // Load MediaPlayer artwork on background queue to avoid blocking UI
            let mediaPlayerImage = await Task.detached {
                artwork.image(at: targetSize)
            }.value
            
            // Show MediaPlayer artwork if no enhanced artwork is loaded
            if self.image == nil {
                self.image = mediaPlayerImage
                
                // CRITICAL FIX: Cache MediaPlayer artwork too if we have song ID
                if let songId = songId, let mediaPlayerImage = mediaPlayerImage {
                    artworkPersistenceService.cacheArtworkForSong(songId, artwork: mediaPlayerImage)
                }
            }
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

// MARK: - Artwork Detail View for Song Detail Screen (Updated)

struct ArtworkDetailView: View {
    let artwork: UIImage?
    let enhancedArtwork: Artwork?
    let isCurrentlyPlaying: Bool
    let isActivelyPlaying: Bool
    let songId: String? // CRITICAL FIX: Add song ID for cache lookup
    
    @State private var displayImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var animationOffset: CGFloat = 0
    
    // CRITICAL FIX: Access to artwork cache service
    private let artworkPersistenceService = DIContainer.shared.artworkPersistenceService
    
    init(artwork: UIImage?, enhancedArtwork: Artwork? = nil, isCurrentlyPlaying: Bool, isActivelyPlaying: Bool, songId: String? = nil) {
        self.artwork = artwork
        self.enhancedArtwork = enhancedArtwork
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
        self.songId = songId
    }
    
    // Convenience initializer for Song objects
    init(song: Song, isCurrentlyPlaying: Bool, isActivelyPlaying: Bool) {
        self.artwork = song.artwork?.image(at: CGSize(width: 600, height: 600))
        self.enhancedArtwork = song.enhancedArtwork
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.isActivelyPlaying = isActivelyPlaying
        self.songId = song.id // CRITICAL FIX: Use song ID for caching
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
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                } else if isLoading {
                    // Show loading state for detail view
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .fill(AppColors.secondaryBackground)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .overlay(
                            VStack(spacing: AppSpacing.small) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(AppColors.primary)
                                
                                Text("Loading artwork...")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        )
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
        .onChange(of: enhancedArtwork) { oldValue, newValue in
            // React to progressive enhancement updates
            if newValue != nil && newValue != oldValue {
                loadDetailArtwork()
            }
        }
    }
    
    private func loadDetailArtwork() {
        Task {
            await loadDetailArtworkAsync()
        }
    }
    
    @MainActor
    private func loadDetailArtworkAsync() {
        isLoading = true
        defer { isLoading = false }
        
        // CRITICAL FIX: Try cached artwork first
        if let songId = songId,
           let cachedImage = artworkPersistenceService.getCachedArtwork(for: songId) {
            self.displayImage = cachedImage
            return
        }
        
        // High resolution for detail view (600x600)
        let targetSize = CGSize(width: 600, height: 600)
        
        // Try MusicKit artwork first (highest quality) - progressive enhancement
        if let enhancedArtwork = enhancedArtwork {
            do {
                if let artworkURL = enhancedArtwork.url(width: Int(targetSize.width), height: Int(targetSize.height)) {
                    let (data, _) = try await URLSession.shared.data(from: artworkURL)
                    if let artworkImage = UIImage(data: data) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.displayImage = artworkImage
                        }
                        
                        // CRITICAL FIX: Cache the high-quality artwork
                        if let songId = songId {
                            artworkPersistenceService.cacheArtworkForSong(songId, artwork: artworkImage)
                        }
                        return
                    }
                }
            } catch {
                // MusicKit artwork failed, fall back to provided artwork
                print("MusicKit detail artwork loading failed: \(error.localizedDescription)")
            }
        }
        
        // Use provided artwork (from MediaPlayer) immediately
        if let artwork = artwork {
            // Show MediaPlayer artwork immediately if no enhanced artwork is loaded
            if displayImage == nil {
                self.displayImage = artwork
                
                // CRITICAL FIX: Cache MediaPlayer artwork too
                if let songId = songId {
                    artworkPersistenceService.cacheArtworkForSong(songId, artwork: artwork)
                }
            }
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

// MARK: - Now Playing Bar Artwork (90x90 for crisp display) (Updated)

struct NowPlayingArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let enhancedArtwork: Artwork?
    let songId: String? // CRITICAL FIX: Add song ID for cache lookup
    
    @State private var image: UIImage?
    @State private var isLoading: Bool = true
    
    // CRITICAL FIX: Access to artwork cache service
    private let artworkPersistenceService = DIContainer.shared.artworkPersistenceService
    
    init(artwork: MPMediaItemArtwork?, enhancedArtwork: Artwork? = nil, songId: String? = nil) {
        self.artwork = artwork
        self.enhancedArtwork = enhancedArtwork
        self.songId = songId
    }
    
    // Convenience initializer for Song objects
    init(song: Song?) {
        self.artwork = song?.artwork
        self.enhancedArtwork = song?.enhancedArtwork
        self.songId = song?.id // CRITICAL FIX: Use song ID for caching
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if isLoading {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.secondaryBackground)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(AppColors.secondaryText)
                    )
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(45 / 4)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .frame(width: 45, height: 45)
        .background(AppColors.secondaryBackground)
        .cornerRadius(AppRadius.small)
        .onAppear {
            loadNowPlayingArtwork()
        }
        .onChange(of: enhancedArtwork) { oldValue, newValue in
            // React to progressive enhancement updates
            if newValue != nil && newValue != oldValue {
                loadNowPlayingArtwork()
            }
        }
    }
    
    private func loadNowPlayingArtwork() {
        Task {
            await loadNowPlayingArtworkAsync()
        }
    }
    
    @MainActor
    private func loadNowPlayingArtworkAsync() {
        isLoading = true
        defer { isLoading = false }
        
        // CRITICAL FIX: Try cached artwork first
        if let songId = songId,
           let cachedImage = artworkPersistenceService.getCachedArtwork(for: songId) {
            self.image = cachedImage
            return
        }
        
        // Crisp size for now playing bar (90x90 for 45pt display)
        let targetSize = CGSize(width: 90, height: 90)
        
        // Try MusicKit artwork first - progressive enhancement
        if let enhancedArtwork = enhancedArtwork {
            do {
                if let artworkURL = enhancedArtwork.url(width: Int(targetSize.width), height: Int(targetSize.height)) {
                    let (data, _) = try await URLSession.shared.data(from: artworkURL)
                    if let artworkImage = UIImage(data: data) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.image = artworkImage
                        }
                        
                        // CRITICAL FIX: Cache the now playing artwork
                        if let songId = songId {
                            artworkPersistenceService.cacheArtworkForSong(songId, artwork: artworkImage)
                        }
                        return
                    }
                }
            } catch {
                // MusicKit artwork failed, fall back to MediaPlayer
                print("MusicKit now playing artwork loading failed: \(error.localizedDescription)")
            }
        }
        
        // Fallback to MediaPlayer artwork (immediate display)
        if let artwork = artwork {
            let mediaPlayerImage = await Task.detached {
                artwork.image(at: targetSize)
            }.value
            
            // Show MediaPlayer artwork immediately if no enhanced artwork is loaded
            if self.image == nil {
                self.image = mediaPlayerImage
                
                // CRITICAL FIX: Cache MediaPlayer artwork too
                if let songId = songId, let mediaPlayerImage = mediaPlayerImage {
                    artworkPersistenceService.cacheArtworkForSong(songId, artwork: mediaPlayerImage)
                }
            }
        }
    }
}
