import SwiftUI

// Environment key for tracking the currently viewed song in detail view
struct CurrentDetailSongKey: EnvironmentKey {
    static let defaultValue: Song? = nil
}

extension EnvironmentValues {
    var currentDetailSong: Song? {
        get { self[CurrentDetailSongKey.self] }
        set { self[CurrentDetailSongKey.self] = newValue }
    }
}
