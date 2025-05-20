import Foundation
import MediaPlayer

struct Song: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let playCount: Int
    let artwork: MPMediaItemArtwork?
    let mediaItem: MPMediaItem
    
    init(from mediaItem: MPMediaItem) {
        self.id = mediaItem.persistentID.stringValue
        self.title = mediaItem.title ?? "Unknown Title"
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.album = mediaItem.albumTitle ?? "Unknown Album"
        self.playCount = mediaItem.playCount
        self.artwork = mediaItem.artwork
        self.mediaItem = mediaItem
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}

extension MPMediaEntityPersistentID {
    var stringValue: String {
        String(format: "%llx", self)
    }
}
