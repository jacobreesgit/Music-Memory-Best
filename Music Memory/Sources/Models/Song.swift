import Foundation
import MediaPlayer

struct Song: Identifiable, Equatable, Hashable {
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
        // Force fresh read of play count
        self.playCount = mediaItem.value(forProperty: MPMediaItemPropertyPlayCount) as? Int ?? 0
        self.artwork = mediaItem.artwork
        self.mediaItem = mediaItem
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        // Only compare by ID for equality
        lhs.id == rhs.id
    }
    
    // Add hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension MPMediaEntityPersistentID {
    var stringValue: String {
        String(format: "%llx", self)
    }
}
