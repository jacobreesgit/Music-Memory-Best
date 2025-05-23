import Foundation
import Combine
import SwiftUI
import UIKit

enum SortOption: String, CaseIterable {
    case playCount = "Play Count"
    case title = "Title"
    
    var systemImage: String {
        switch self {
        case .playCount:
            return "number"
        case .title:
            return "textformat.abc"
        }
    }
    
    var defaultDirection: SortDirection {
        switch self {
        case .playCount:
            return .descending // Highest play count first
        case .title:
            return .ascending // Alphabetical A-Z order
        }
    }
}

enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
    
    var systemImage: String {
        switch self {
        case .ascending:
            return "chevron.up"
        case .descending:
            return "chevron.down"
        }
    }
}

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var permissionStatus: AppPermissionStatus = .unknown
    @Published var sortOption: SortOption = .playCount
    @Published var sortDirection: SortDirection = .descending
    
    private var allSongs: [Song] = [] // Store original unsorted songs
    private let musicLibraryService: MusicLibraryServiceProtocol
    private let logger: LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    let errorSubject = PassthroughSubject<AppError, Never>()
    
    init(
        musicLibraryService: MusicLibraryServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.musicLibraryService = musicLibraryService
        self.logger = logger
        setupErrorHandling()
    }
    
    private func setupErrorHandling() {
        errorSubject
            .receive(on: RunLoop.main)
            .sink { error in
                NotificationCenter.default.post(
                    name: .appErrorOccurred,
                    object: error
                )
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func loadSongs() async {
        isLoading = true
        defer { isLoading = false }
        
        logger.log("Loading songs", level: .info)
        
        do {
            // Check current permission status first
            await updatePermissionStatus(musicLibraryService.checkPermissionStatus())
            
            // If permission is granted, load songs
            if permissionStatus == .granted {
                let fetchedSongs = try await musicLibraryService.fetchSongs()
                self.allSongs = fetchedSongs
                applySorting()
                logger.log("Loaded \(fetchedSongs.count) songs successfully", level: .info)
            }
        } catch {
            logger.log("Error loading songs: \(error.localizedDescription)", level: .error)
            handleError(error)
        }
    }
    
    @MainActor
    func requestPermission() async -> Bool {
        // Set the state to "requested" to show appropriate UI
        await updatePermissionStatus(.requested)
        
        // Request the actual permission
        let granted = await musicLibraryService.requestPermission()
        
        // Update status based on result
        await updatePermissionStatus(granted ? .granted : .denied)
        
        // If permission was granted, load the songs
        if granted {
            await loadSongs()
        }
        
        return granted
    }
    
    @MainActor
    func updatePermissionStatus(_ status: AppPermissionStatus) async {
        permissionStatus = status
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let appState = appDelegate.appState {
            appState.musicLibraryPermissionStatus = status
        }
    }
    
    func updateSortOption(_ option: SortOption) {
        if sortOption == option {
            // Same option selected - toggle direction
            sortDirection = sortDirection == .descending ? .ascending : .descending
        } else {
            // Different option selected - use that option's default direction
            sortOption = option
            sortDirection = option.defaultDirection
        }
        
        applySorting()
        
        // Provide haptic feedback for selection change
        AppHaptics.selectionChanged()
        
        logger.log("Updated sorting to \(sortOption.rawValue) \(sortDirection.rawValue)", level: .info)
    }
    
    private func applySorting() {
        switch sortOption {
        case .playCount:
            if sortDirection == .descending {
                songs = allSongs.sorted { $0.playCount > $1.playCount }
            } else {
                songs = allSongs.sorted { $0.playCount < $1.playCount }
            }
        case .title:
            if sortDirection == .ascending {
                songs = allSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            } else {
                songs = allSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            errorSubject.send(appError)
        } else {
            errorSubject.send(AppError.unknown(error))
        }
    }
}

// MARK: - Preview Factory
extension SongListViewModel {
    static func preview(withSongs songs: [Song]) -> SongListViewModel {
        let logger = Logger()
        let mockService = PreviewMusicLibraryService(mockSongs: songs)
        
        let viewModel = SongListViewModel(
            musicLibraryService: mockService,
            logger: logger
        )
        
        // Immediately populate the view model for previews
        viewModel.allSongs = songs
        viewModel.songs = songs
        viewModel.permissionStatus = .granted
        viewModel.isLoading = false
        
        return viewModel
    }
}
