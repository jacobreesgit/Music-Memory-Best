import Foundation
import CoreData
import Combine

// MARK: - Query Strategy
enum QueryStrategy {
    case useRecentPlays     // Maximum detail for short ranges (0-30 days)
    case useDailyAggregates // Pre-calculated daily summaries (31-365 days)
    case useWeeklyAggregates // Weekly summaries for very long ranges (365+ days)
}

// MARK: - Data Manager
class DataManager: ObservableObject {
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Smart Query Strategy
    func queryPlaysForDateRange(_ startDate: Date, _ endDate: Date) -> QueryStrategy {
        let daysDifference = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        switch daysDifference {
        case 0...30:
            return .useRecentPlays // Maximum detail for short ranges
        case 31...365:
            return .useDailyAggregates // Pre-calculated daily summaries
        default:
            return .useWeeklyAggregates // Weekly summaries for very long ranges
        }
    }
    
    // MARK: - Record Song Completion
    func recordSongCompletion(
        songID: String,
        albumID: String,
        artistID: String,
        playDuration: TimeInterval,
        completionPercentage: Double,
        source: String = "AppleMusic"
    ) {
        let context = persistenceController.container.viewContext
        
        // Create new RecentPlay record
        let recentPlay = RecentPlay(context: context)
        recentPlay.id = UUID()
        recentPlay.songID = songID
        recentPlay.albumID = albumID
        recentPlay.artistID = artistID
        recentPlay.timestamp = Date()
        recentPlay.playDuration = playDuration
        recentPlay.completionPercentage = completionPercentage
        recentPlay.source = source
        recentPlay.sessionID = getCurrentSessionID()
        
        // Update/create daily aggregates for all three entity types
        updateDailyAggregates(for: songID, entityType: "song", on: Date(), context: context)
        updateDailyAggregates(for: albumID, entityType: "album", on: Date(), context: context)
        updateDailyAggregates(for: artistID, entityType: "artist", on: Date(), context: context)
        
        // Save changes
        do {
            try context.save()
            print("Song completion recorded: \(songID)")
            
            // Trigger chart recalculation
            NotificationCenter.default.post(name: .chartUpdateNeeded, object: nil)
        } catch {
            print("Error saving song completion: \(error)")
        }
    }
    
    // MARK: - Update Daily Aggregates
    private func updateDailyAggregates(for entityID: String, entityType: String, on date: Date, context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let fetchRequest: NSFetchRequest<DailyAggregate> = DailyAggregate.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "entityID == %@ AND entityType == %@ AND date == %@", entityID, entityType, startOfDay as NSDate)
        
        do {
            let existingAggregates = try context.fetch(fetchRequest)
            
            if let aggregate = existingAggregates.first {
                // Update existing aggregate
                aggregate.playCount += 1
            } else {
                // Create new aggregate
                let newAggregate = DailyAggregate(context: context)
                newAggregate.entityID = entityID
                newAggregate.entityType = entityType
                newAggregate.date = startOfDay
                newAggregate.playCount = 1
                newAggregate.totalDuration = 0
                newAggregate.averageCompletion = 0
            }
        } catch {
            print("Error updating daily aggregates: \(error)")
        }
    }
    
    // MARK: - Get Current Session ID
    private func getCurrentSessionID() -> String {
        // Simple session management - could be enhanced with more sophisticated logic
        let sessionKey = "currentSessionID"
        let lastSessionTime = "lastSessionTime"
        let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
        
        let now = Date()
        let lastTime = UserDefaults.standard.object(forKey: lastSessionTime) as? Date ?? Date.distantPast
        
        if now.timeIntervalSince(lastTime) > sessionTimeout {
            // Create new session
            let newSessionID = UUID().uuidString
            UserDefaults.standard.set(newSessionID, forKey: sessionKey)
            UserDefaults.standard.set(now, forKey: lastSessionTime)
            return newSessionID
        } else {
            // Continue existing session
            UserDefaults.standard.set(now, forKey: lastSessionTime)
            return UserDefaults.standard.string(forKey: sessionKey) ?? UUID().uuidString
        }
    }
    
    // MARK: - Fetch Recent Plays
    func fetchRecentPlays(limit: Int = 100) -> [RecentPlay] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<RecentPlay> = RecentPlay.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecentPlay.timestamp, ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching recent plays: \(error)")
            return []
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chartUpdateNeeded = Notification.Name("chartUpdateNeeded")
}