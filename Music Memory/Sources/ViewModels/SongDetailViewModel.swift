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
        
        // Listen for song play completion notifications
        setupPlayCompletionListener()
    }
    
    private func setupPlayCompletionListener() {
        NotificationCenter.default.publisher(for: .songPlayCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let songId = notification.userInfo?[Notification.SongKeys.completedSongId] as? String,
                      songId == self.song.id else { return }
                
                // The play count has been incremented, trigger a refresh
                self.logger.log("Song play completed for '\(self.song.title)' - refreshing view", level: .info)
                
                // Force a view update by reassigning the song
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
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
        
        // Format last played date with relative time formatting
        if let lastPlayedDate = mediaItem.value(forProperty: MPMediaItemPropertyLastPlayedDate) as? Date {
            self.lastPlayedDate = formatRelativeTime(from: lastPlayedDate)
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
    
    /// Formats a date relative to the current time in user-friendly terms
    private func formatRelativeTime(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // Handle future dates (shouldn't happen but just in case)
        guard timeInterval >= 0 else {
            return "Recently"
        }
        
        let totalSeconds = Int(timeInterval)
        let totalMinutes = totalSeconds / 60
        let totalHours = totalMinutes / 60
        let totalDays = totalHours / 24
        let totalWeeks = totalDays / 7
        let totalMonths = totalDays / 30
        let totalYears = totalDays / 365
        
        switch totalSeconds {
        case 0..<10:
            return "Just now"
            
        case 10..<60: // Less than 1 minute - show seconds
            return "\(totalSeconds) seconds ago"
            
        case 60..<3600: // Less than 1 hour - show minutes and seconds
            let minutes = totalMinutes
            let remainingSeconds = totalSeconds % 60
            
            if minutes == 1 {
                if remainingSeconds == 0 {
                    return "1 minute ago"
                } else if remainingSeconds == 1 {
                    return "1 minute 1 second ago"
                } else {
                    return "1 minute \(remainingSeconds) seconds ago"
                }
            } else {
                if remainingSeconds == 0 {
                    return "\(minutes) minutes ago"
                } else if remainingSeconds == 1 {
                    return "\(minutes) minutes 1 second ago"
                } else {
                    return "\(minutes) minutes \(remainingSeconds) seconds ago"
                }
            }
            
        case 3600..<86400: // Less than 1 day - show hours and minutes
            let hours = totalHours
            let remainingMinutes = (totalMinutes % 60)
            
            if hours == 1 {
                if remainingMinutes == 0 {
                    return "1 hour ago"
                } else if remainingMinutes == 1 {
                    return "1 hour 1 minute ago"
                } else {
                    return "1 hour \(remainingMinutes) minutes ago"
                }
            } else {
                if remainingMinutes == 0 {
                    return "\(hours) hours ago"
                } else if remainingMinutes == 1 {
                    return "\(hours) hours 1 minute ago"
                } else {
                    return "\(hours) hours \(remainingMinutes) minutes ago"
                }
            }
            
        case 86400..<172800: // 1-2 days - show days and hours for more recent activity
            let days = totalDays
            let remainingHours = (totalHours % 24)
            
            if days == 1 {
                if remainingHours == 0 {
                    return "1 day ago"
                } else if remainingHours == 1 {
                    return "1 day 1 hour ago"
                } else {
                    return "1 day \(remainingHours) hours ago"
                }
            } else {
                if remainingHours == 0 {
                    return "\(days) days ago"
                } else if remainingHours == 1 {
                    return "\(days) days 1 hour ago"
                } else {
                    return "\(days) days \(remainingHours) hours ago"
                }
            }
            
        case 172800..<604800: // 2-7 days - just show days
            return totalDays == 1 ? "1 day ago" : "\(totalDays) days ago"
            
        case 604800..<2592000: // Less than 1 month
            return totalWeeks == 1 ? "1 week ago" : "\(totalWeeks) weeks ago"
            
        case 2592000..<31536000: // Less than 1 year
            return totalMonths == 1 ? "1 month ago" : "\(totalMonths) months ago"
            
        default:
            return totalYears == 1 ? "1 year ago" : "\(totalYears) years ago"
        }
    }
    
    private func loadArtwork() {
        if let artwork = song.artwork {
            // Load the artwork at an appropriate size for details view
            self.artwork = artwork.image(at: CGSize(width: 300, height: 300))
        }
    }
}
