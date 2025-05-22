import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    @Published var songListPath = NavigationPath()
    private var songStack: [Song] = [] // Keep track of the song navigation stack
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Monitor path changes to keep songStack in sync
        $songListPath
            .sink { [weak self] newPath in
                self?.syncSongStack(with: newPath)
            }
            .store(in: &cancellables)
    }
    
    var currentDetailSong: Song? {
        return songStack.last
    }
    
    func navigateToSongDetail(song: Song) {
        songListPath.append(song)
        songStack.append(song)
    }
    
    func popToRoot() {
        songListPath = NavigationPath()
        songStack.removeAll()
    }
    
    func popToPrevious() {
        if !songListPath.isEmpty {
            songListPath.removeLast()
            if !songStack.isEmpty {
                songStack.removeLast()
            }
        }
    }
    
    private func syncSongStack(with path: NavigationPath) {
        // If the path count is less than our song stack,
        // it means someone navigated back (back button or swipe)
        let pathCount = path.count
        let stackCount = songStack.count
        
        if pathCount < stackCount {
            // Remove items from the end of songStack to match path count
            let itemsToRemove = stackCount - pathCount
            for _ in 0..<itemsToRemove {
                songStack.removeLast()
            }
        }
    }
}
