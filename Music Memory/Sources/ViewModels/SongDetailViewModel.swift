import Foundation
import UIKit
import Combine
@preconcurrency import MediaPlayer
import MusicKit

class SongDetailViewModel: ObservableObject {
    @Published var song: Song
    @Published var artwork: UIImage?
    
    // Enhanced song details with MusicKit integration
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
    @Published var isExplicit: Bool
    @Published var enhancementStatus: String
    
    private let logger: LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(song: Song, logger: LoggerProtocol) {
        self.song = song
        self.logger = logger
        
        // Initialize with default values
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
        self.isExplicit = false
        self.enhancementStatus = ""
        
        // Extract all metadata using enhanced methods
        extractEnhancedMetadata()
        
        // Load artwork (with MusicKit enhancement)
        loadEnhancedArtwork()
        
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
    
    private func extractEnhancedMetadata() {
        let mediaItem = song.mediaItem
        
        // Use enhanced genre from MusicKit if available, fallback to MediaPlayer
        self.genre = song.enhancedGenre
        
        // Use enhanced duration from MusicKit if available
        let durationInSeconds = song.enhancedDuration
        if durationInSeconds > 0 {
            let minutes = Int(durationInSeconds / 60)
            let seconds = Int(durationInSeconds.truncatingRemainder(dividingBy: 60))
            self.duration = String(format: "%d:%02d", minutes, seconds)
        } else {
            self.duration = "Unknown"
        }
        
        // Use enhanced release date
        if let releaseDate = song.enhancedReleaseDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            self.releaseDate = formatter.string(from: releaseDate)
        } else {
            self.releaseDate = "Unknown"
        }
        
        // Use enhanced composer
        self.composer = song.enhancedComposer
        
        // Format last played date with relative time formatting
        if let lastPlayedDate = mediaItem.value(forProperty: MPMediaItemPropertyLastPlayedDate) as? Date {
            self.lastPlayedDate = formatRelativeTime(from: lastPlayedDate)
        } else {
            self.lastPlayedDate = "Never"
        }
        
        self.skipCount = mediaItem.value(forProperty: MPMediaItemPropertySkipCount) as? Int ?? 0
        self.rating = mediaItem.value(forProperty: MPMediaItemPropertyRating) as? Int ?? 0
        
        // Use enhanced track and disc information
        let trackInfo = song.enhancedTrackInfo
        self.trackNumber = trackInfo.trackNumber
        self.discNumber = trackInfo.discNumber
        
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
        
        // MusicKit-specific enhancements
        self.isExplicit = song.isExplicit
        
        // Enhancement status
        if song.hasEnhancedData {
            self.enhancementStatus = "Enhanced with MusicKit"
        } else {
            self.enhancementStatus = "Ready for Enhancement"
        }
        
        logger.log("Extracted metadata for '\(song.title)' - Enhanced: \(song.hasEnhancedData)", level: .debug)
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
    
    private func loadEnhancedArtwork() {
        Task {
            await loadEnhancedArtworkAsync()
        }
    }
    
    @MainActor
    private func loadEnhancedArtworkAsync() {
        // Try MusicKit artwork first for higher quality
        if let enhancedArtwork = song.enhancedArtwork {
            Task {
                do {
                    // MusicKit Artwork uses url(width:height:) method
                    if let artworkURL = enhancedArtwork.url(width: 600, height: 600) {
                        let (data, _) = try await URLSession.shared.data(from: artworkURL)
                        if let artworkImage = UIImage(data: data) {
                            self.artwork = artworkImage
                            logger.log("Loaded MusicKit artwork for '\(song.title)'", level: .debug)
                            return
                        }
                    }
                } catch {
                    logger.log("Failed to load MusicKit artwork for '\(song.title)': \(error.localizedDescription)", level: .debug)
                    // Fall through to MediaPlayer artwork
                }
            }
        }
        
        // Fallback to MediaPlayer artwork
        if let mpArtwork = song.artwork {
            Task {
                let image = await Task.detached {
                    mpArtwork.image(at: CGSize(width: 600, height: 600))
                }.value
                self.artwork = image
                logger.log("Loaded MediaPlayer artwork for '\(song.title)'", level: .debug)
            }
        }
    }
}
