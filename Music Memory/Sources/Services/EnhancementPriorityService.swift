import Foundation
import Combine

// MARK: - Priority Levels

enum EnhancementPriority: Int, CaseIterable, Comparable {
    case urgent = 0        // Currently playing song (especially non-library)
    case high = 1          // Top 50 in current sort order
    case medium = 2        // Top/bottom 50 for other sort orders
    case low = 3           // Remaining songs with >0 play count
    case background = 4    // Never-played songs during idle time
    
    static func < (lhs: EnhancementPriority, rhs: EnhancementPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var description: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .background: return "Background"
        }
    }
}

// MARK: - Priority Queue Item

struct PriorityQueueItem: Comparable, Identifiable {
    let id: String
    let song: Song
    let priority: EnhancementPriority
    let reason: String
    let timestamp: Date
    
    static func < (lhs: PriorityQueueItem, rhs: PriorityQueueItem) -> Bool {
        // First compare by priority
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        // If same priority, newer items first
        return lhs.timestamp > rhs.timestamp
    }
    
    static func == (lhs: PriorityQueueItem, rhs: PriorityQueueItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Enhancement Stats

struct EnhancementStats {
    let totalSongs: Int
    let enhancedSongs: Int
    let queuedSongs: Int
    let urgentRemaining: Int
    let highRemaining: Int
    let mediumRemaining: Int
    let lowRemaining: Int
    let backgroundRemaining: Int
    
    var progress: Double {
        guard totalSongs > 0 else { return 0 }
        return Double(enhancedSongs) / Double(totalSongs)
    }
}

// MARK: - Lightweight Priority Service Protocol

protocol EnhancementPriorityServiceProtocol {
    func updateSongsList(_ songs: [Song])
    func setCurrentSortOrder(_ descriptor: SortDescriptor)
    func setCurrentlyPlayingSong(_ song: Song?, isFromLibrary: Bool)
    func getNextBatchForEnhancement(batchSize: Int) -> [Song]
    func markSongAsEnhanced(_ songId: String)
    func getEnhancementStats() -> EnhancementStats
    func setAppIdleState(_ isIdle: Bool)
}

// MARK: - Optimized Priority Service

class EnhancementPriorityService: EnhancementPriorityServiceProtocol {
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "enhancement.priority", qos: .utility)
    
    // Core data - protected by queue
    private var allSongs: [Song] = []
    private var enhancedSongIds: Set<String> = []
    private var priorityQueue: [PriorityQueueItem] = []
    private var queuedSongIds: Set<String> = []
    
    // Context tracking
    private var currentSortDescriptor: SortDescriptor?
    private var sortContexts: [String: SortContext] = [:]
    private var currentlyPlayingSong: Song?
    private var isCurrentSongFromLibrary: Bool = true
    private var isAppIdle: Bool = false
    
    // Performance optimization
    private var needsRebuild: Bool = false
    private var lastRebuildTime: Date = Date()
    private let rebuildCooldown: TimeInterval = 1.0 // Only rebuild once per second max
    
    // Constants
    private let topBottomCount = 50
    
    init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    // MARK: - Public Interface (Non-blocking)
    
    func updateSongsList(_ songs: [Song]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.allSongs = songs
            self.scheduleRebuild()
            self.logger.log("Updated songs list with \(songs.count) songs", level: .debug)
        }
    }
    
    func setCurrentSortOrder(_ descriptor: SortDescriptor) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentSortDescriptor = descriptor
            self.scheduleRebuild()
            self.logger.log("Updated current sort order to \(descriptor.key)", level: .debug)
        }
    }
    
    func setCurrentlyPlayingSong(_ song: Song?, isFromLibrary: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentlyPlayingSong = song
            self.isCurrentSongFromLibrary = isFromLibrary
            
            if let song = song {
                if !isFromLibrary {
                    self.logger.log("Non-library song '\(song.title)' needs urgent enhancement", level: .info)
                }
                // Immediate rebuild for currently playing changes
                self.performRebuildIfNeeded()
            }
        }
    }
    
    func getNextBatchForEnhancement(batchSize: Int) -> [Song] {
        return queue.sync { [weak self] in
            guard let self = self else { return [] }
            
            self.performRebuildIfNeeded()
            
            // Sort priority queue and take next batch
            self.priorityQueue.sort()
            
            let batch = self.priorityQueue
                .prefix(batchSize)
                .map { $0.song }
            
            if !batch.isEmpty {
                let priorities = self.priorityQueue.prefix(batchSize).map { $0.priority.description }
                self.logger.log("Next enhancement batch: \(batch.count) songs with priorities: \(priorities.joined(separator: ", "))", level: .debug)
            }
            
            return Array(batch)
        }
    }
    
    func markSongAsEnhanced(_ songId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.enhancedSongIds.insert(songId)
            
            // Remove from priority queue
            self.priorityQueue.removeAll { $0.id == songId }
            self.queuedSongIds.remove(songId)
        }
    }
    
    func getEnhancementStats() -> EnhancementStats {
        return queue.sync { [weak self] in
            guard let self = self else {
                return EnhancementStats(totalSongs: 0, enhancedSongs: 0, queuedSongs: 0, urgentRemaining: 0, highRemaining: 0, mediumRemaining: 0, lowRemaining: 0, backgroundRemaining: 0)
            }
            
            let priorityCounts = Dictionary(grouping: self.priorityQueue, by: { $0.priority })
            
            return EnhancementStats(
                totalSongs: self.allSongs.count,
                enhancedSongs: self.enhancedSongIds.count,
                queuedSongs: self.priorityQueue.count,
                urgentRemaining: priorityCounts[.urgent]?.count ?? 0,
                highRemaining: priorityCounts[.high]?.count ?? 0,
                mediumRemaining: priorityCounts[.medium]?.count ?? 0,
                lowRemaining: priorityCounts[.low]?.count ?? 0,
                backgroundRemaining: priorityCounts[.background]?.count ?? 0
            )
        }
    }
    
    func setAppIdleState(_ isIdle: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.isAppIdle != isIdle else { return }
            
            self.isAppIdle = isIdle
            self.logger.log("App idle state changed to: \(isIdle)", level: .debug)
            
            if isIdle {
                self.scheduleRebuild()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func scheduleRebuild() {
        needsRebuild = true
    }
    
    private func performRebuildIfNeeded() {
        guard needsRebuild else { return }
        
        // Rate limit rebuilds
        let now = Date()
        guard now.timeIntervalSince(lastRebuildTime) >= rebuildCooldown else { return }
        
        lastRebuildTime = now
        needsRebuild = false
        
        rebuildSortContexts()
        rebuildPriorityQueue()
    }
    
    private func rebuildSortContexts() {
        sortContexts.removeAll()
        
        // Build context for all possible sort orders
        for option in SortOption.allCases {
            for direction in SortDirection.allCases {
                let descriptor = SortDescriptor(option: option, direction: direction)
                let context = SortContext(songs: allSongs, descriptor: descriptor)
                sortContexts[descriptor.key] = context
            }
        }
    }
    
    private func rebuildPriorityQueue() {
        // Clear current queue
        priorityQueue.removeAll()
        queuedSongIds.removeAll()
        
        // Add songs by priority
        addUrgentPrioritySongs()
        addHighPrioritySongs()
        addMediumPrioritySongs()
        addLowPrioritySongs()
        
        // Only add background priority if app is idle
        if isAppIdle {
            addBackgroundPrioritySongs()
        }
        
        // Sort the queue
        priorityQueue.sort()
        
        let priorityCounts = Dictionary(grouping: priorityQueue, by: { $0.priority })
        let summary = EnhancementPriority.allCases.compactMap { priority in
            guard let count = priorityCounts[priority]?.count, count > 0 else { return nil }
            return "\(priority.description): \(count)"
        }.joined(separator: ", ")
        
        if !summary.isEmpty {
            logger.log("Rebuilt priority queue: \(summary)", level: .debug)
        }
    }
    
    private func addUrgentPrioritySongs() {
        guard let currentSong = currentlyPlayingSong else { return }
        guard !enhancedSongIds.contains(currentSong.id) else { return }
        
        let reason = isCurrentSongFromLibrary ? "Currently playing" : "Currently playing (non-library)"
        addToPriorityQueue(song: currentSong, priority: .urgent, reason: reason)
    }
    
    private func addHighPrioritySongs() {
        guard let currentDescriptor = currentSortDescriptor,
              let currentContext = sortContexts[currentDescriptor.key] else { return }
        
        // Top 50 songs in current sort order
        for song in currentContext.topSongs {
            guard !enhancedSongIds.contains(song.id) else { continue }
            addToPriorityQueue(song: song, priority: .high, reason: "Top 50 in current sort (\(currentDescriptor.key))")
        }
    }
    
    private func addMediumPrioritySongs() {
        guard let currentDescriptor = currentSortDescriptor else { return }
        
        // Top and bottom 50 for ALL other sort orders
        for (key, context) in sortContexts {
            // Skip current sort order (handled in high priority)
            guard key != currentDescriptor.key else { continue }
            
            // Add top songs
            for song in context.topSongs {
                guard !enhancedSongIds.contains(song.id) else { continue }
                guard !queuedSongIds.contains(song.id) else { continue } // Avoid duplicates
                addToPriorityQueue(song: song, priority: .medium, reason: "Top 50 for \(key)")
            }
            
            // Add bottom songs
            for song in context.bottomSongs {
                guard !enhancedSongIds.contains(song.id) else { continue }
                guard !queuedSongIds.contains(song.id) else { continue } // Avoid duplicates
                addToPriorityQueue(song: song, priority: .medium, reason: "Bottom 50 for \(key)")
            }
        }
    }
    
    private func addLowPrioritySongs() {
        // Remaining songs with >0 play count
        for song in allSongs {
            guard song.displayedPlayCount > 0 else { continue }
            guard !enhancedSongIds.contains(song.id) else { continue }
            guard !queuedSongIds.contains(song.id) else { continue }
            
            addToPriorityQueue(song: song, priority: .low, reason: "Has play count (\(song.displayedPlayCount))")
        }
    }
    
    private func addBackgroundPrioritySongs() {
        // Never-played songs (only during app idle time)
        for song in allSongs {
            guard song.displayedPlayCount == 0 else { continue }
            guard !enhancedSongIds.contains(song.id) else { continue }
            guard !queuedSongIds.contains(song.id) else { continue }
            
            addToPriorityQueue(song: song, priority: .background, reason: "No plays (background)")
        }
    }
    
    private func addToPriorityQueue(song: Song, priority: EnhancementPriority, reason: String) {
        let item = PriorityQueueItem(
            id: song.id,
            song: song,
            priority: priority,
            reason: reason,
            timestamp: Date()
        )
        
        priorityQueue.append(item)
        queuedSongIds.insert(song.id)
    }
}

// MARK: - Sort Context (Unchanged)

struct SortContext {
    let descriptor: SortDescriptor
    let topSongs: [Song]        // Top 50 for this sort
    let bottomSongs: [Song]     // Bottom 50 for this sort (for reverse viewing)
    
    init(songs: [Song], descriptor: SortDescriptor) {
        self.descriptor = descriptor
        
        // Sort songs according to descriptor
        let sortedSongs = Self.sortSongs(songs, by: descriptor)
        
        // Take top 50 and bottom 50
        self.topSongs = Array(sortedSongs.prefix(50))
        self.bottomSongs = Array(sortedSongs.suffix(50))
    }
    
    private static func sortSongs(_ songs: [Song], by descriptor: SortDescriptor) -> [Song] {
        switch descriptor.option {
        case .playCount:
            if descriptor.direction == .descending {
                return songs.sorted { $0.displayedPlayCount > $1.displayedPlayCount }
            } else {
                return songs.sorted { $0.displayedPlayCount < $1.displayedPlayCount }
            }
        case .title:
            if descriptor.direction == .ascending {
                return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            } else {
                return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
            }
        }
    }
}
