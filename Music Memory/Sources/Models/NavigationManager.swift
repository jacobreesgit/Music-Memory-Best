import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    @Published var songListPath = NavigationPath()
    
    func navigateToSongDetail(song: Song) {
        songListPath.append(song)
    }
    
    func popToRoot() {
        songListPath = NavigationPath()
    }
    
    func popToPrevious() {
        if !songListPath.isEmpty {
            songListPath.removeLast()
        }
    }
}
