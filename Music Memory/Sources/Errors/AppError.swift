import Foundation

enum AppError: Error, Identifiable, Equatable {
    case permissionDenied
    case noMediaItemsFound
    case failedToFetchSongs(underlyingError: Error)
    case unknown(Error)
    
    var id: String {
        switch self {
        case .permissionDenied:
            return "permissionDenied"
        case .noMediaItemsFound:
            return "noMediaItemsFound"
        case .failedToFetchSongs:
            return "failedToFetchSongs"
        case .unknown:
            return "unknown"
        }
    }
    
    var userMessage: String {
        switch self {
        case .permissionDenied:
            return "Please allow Music Memory to access your music library in Settings."
        case .noMediaItemsFound:
            return "No songs were found in your music library."
        case .failedToFetchSongs(let error):
            return "Failed to fetch songs: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .permissionDenied:
            return true
        case .noMediaItemsFound:
            return false
        case .failedToFetchSongs:
            return true
        case .unknown:
            return false
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Open Settings and grant Music Memory access to your music library."
        case .failedToFetchSongs:
            return "Try again later or restart the app."
        default:
            return nil
        }
    }
    
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

extension NSNotification.Name {
    static let appErrorOccurred = NSNotification.Name("appErrorOccurred")
    static let songsListUpdated = NSNotification.Name("songsListUpdated")
    static let songPlayCompleted = NSNotification.Name("songPlayCompleted")
}

// Notification info keys
extension Notification {
    enum SongKeys {
        static let updatedSongs = "updatedSongs"
        static let completedSongId = "completedSongId"
    }
}
