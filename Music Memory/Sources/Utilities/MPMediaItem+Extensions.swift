import MediaPlayer

extension MPMediaItem {
    var title: String? {
        return value(forProperty: MPMediaItemPropertyTitle) as? String
    }
    
    var artist: String? {
        return value(forProperty: MPMediaItemPropertyArtist) as? String
    }
    
    var albumTitle: String? {
        return value(forProperty: MPMediaItemPropertyAlbumTitle) as? String
    }
    
    var playCount: Int {
        return value(forProperty: MPMediaItemPropertyPlayCount) as? Int ?? 0
    }
}
