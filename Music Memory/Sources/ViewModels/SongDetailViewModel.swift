import Foundation
import UIKit
import Combine
import MediaPlayer

class SongDetailViewModel: ObservableObject {
    @Published var song: Song
    @Published var artwork: UIImage?
    
    private let logger: LoggerProtocol
    
    init(song: Song, logger: LoggerProtocol) {
        self.song = song
        self.logger = logger
        loadArtwork()
    }
    
    private func loadArtwork() {
        if let artwork = song.artwork {
            // Load the artwork at an appropriate size for details view
            self.artwork = artwork.image(at: CGSize(width: 300, height: 300))
        }
    }
}
