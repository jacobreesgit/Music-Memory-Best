import Foundation
import UIKit
import Combine
import MediaPlayer

class SongDetailViewModel: ObservableObject {
    @Published var song: Song
    @Published var artwork: UIImage?
    
    // Additional song details
    @Published var genre: String
    @Published var duration: String
    @Published var releaseDate: String
    @Published var composer: String
    @Published var lastPlayedDate: String
    @Published var skipCount: Int
    @Published var rating: Int
    @Published var trackNumber: String
    @Published var discNumber: String
    @Published var bpm: Int
    @Published var fileSize: String
    
    private let logger: LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(song: Song, logger: LoggerProtocol) {
        self.song = song
        self.logger = logger
        
        // Extract metadata
        self.genre = ""
        self.duration = ""
        self.releaseDate = ""
        self.composer = ""
        self.lastPlayedDate = ""
        self.skipCount = 0
        self.rating = 0
        self.trackNumber = ""
        self.discNumber = ""
        self.bpm = 0
        self.fileSize = ""
        
        // Extract all metadata
        extractMetadata()
        
        // Load artwork
        loadArtwork()
        
        // Listen for song list updates to refresh this song's data
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Listen for song list updates
        NotificationCenter.default.publisher(for: .songsListUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let songs = notification.object as? [Song],
                      let self = self else { return }
                
                // Find our song in the updated list
                if let updatedSong = songs.first(where: { $0.id == self.song.id }) {
                    self.updateSong(updatedSong)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateSong(_ updatedSong: Song) {
        logger.log("Updating song details for: \(updatedSong.title)", level: .info)
        
        // Update the song
        self.song = updatedSong
        
        // Re-extract metadata with the updated song
        extractMetadata()
        
        // Reload artwork in case it changed
        loadArtwork()
    }
    
    private func extractMetadata() {
        let mediaItem = song.mediaItem
        
        self.genre = mediaItem.value(forProperty: MPMediaItemPropertyGenre) as? String ?? "Unknown"
        
        // Format duration from seconds to mm:ss
        if let durationInSeconds = mediaItem.value(forProperty: MPMediaItemPropertyPlaybackDuration) as? TimeInterval {
            let minutes = Int(durationInSeconds / 60)
            let seconds = Int(durationInSeconds.truncatingRemainder(dividingBy: 60))
            self.duration = String(format: "%d:%02d", minutes, seconds)
        } else {
            self.duration = "Unknown"
        }
        
        // Format release date if available
        if let releaseDate = mediaItem.value(forProperty: MPMediaItemPropertyReleaseDate) as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            self.releaseDate = formatter.string(from: releaseDate)
        } else {
            self.releaseDate = "Unknown"
        }
        
        self.composer = mediaItem.value(forProperty: MPMediaItemPropertyComposer) as? String ?? "Unknown"
        
        // Format last played date if available
        if let lastPlayedDate = mediaItem.value(forProperty: MPMediaItemPropertyLastPlayedDate) as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            self.lastPlayedDate = formatter.string(from: lastPlayedDate)
        } else {
            self.lastPlayedDate = "Never"
        }
        
        self.skipCount = mediaItem.value(forProperty: MPMediaItemPropertySkipCount) as? Int ?? 0
        self.rating = mediaItem.value(forProperty: MPMediaItemPropertyRating) as? Int ?? 0
        
        // Track and disc numbers
        if let trackNumber = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackNumber) as? Int {
            let totalTracks = mediaItem.value(forProperty: MPMediaItemPropertyAlbumTrackCount) as? Int
            if let total = totalTracks {
                self.trackNumber = "\(trackNumber) of \(total)"
            } else {
                self.trackNumber = "\(trackNumber)"
            }
        } else {
            self.trackNumber = "Unknown"
        }
        
        if let discNumber = mediaItem.value(forProperty: MPMediaItemPropertyDiscNumber) as? Int {
            let totalDiscs = mediaItem.value(forProperty: MPMediaItemPropertyDiscCount) as? Int
            if let total = totalDiscs {
                self.discNumber = "\(discNumber) of \(total)"
            } else {
                self.discNumber = "\(discNumber)"
            }
        } else {
            self.discNumber = "Unknown"
        }
        
        self.bpm = mediaItem.value(forProperty: MPMediaItemPropertyBeatsPerMinute) as? Int ?? 0
        
        // File size
        if let assetURL = mediaItem.value(forProperty: MPMediaItemPropertyAssetURL) as? URL {
            do {
                let resources = try assetURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resources.fileSize {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useMB]
                    formatter.countStyle = .file
                    self.fileSize = formatter.string(fromByteCount: Int64(fileSize))
                } else {
                    self.fileSize = "Unknown"
                }
            } catch {
                self.fileSize = "Unknown"
                logger.log("Failed to get file size: \(error.localizedDescription)", level: .error)
            }
        } else {
            self.fileSize = "Unknown"
        }
    }
    
    private func loadArtwork() {
        if let artwork = song.artwork {
            // Load the artwork at an appropriate size for details view
            self.artwork = artwork.image(at: CGSize(width: 300, height: 300))
        }
    }
}
