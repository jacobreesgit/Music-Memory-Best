import Foundation

protocol RankHistoryServiceProtocol {
    func saveRankSnapshot(songs: [Song], sortDescriptor: SortDescriptor)
    func getRankChanges(for songs: [Song], sortDescriptor: SortDescriptor) -> [String: RankChange]
    func cleanupOldSnapshots()
    func clearAllRankHistory()
    func getOldestSnapshotDate() -> Date?
    func getNewestSnapshotDate() -> Date?
}

class RankHistoryService: RankHistoryServiceProtocol {
    private let logger: LoggerProtocol
    private let maxSnapshotsPerSort = 10 // Keep last 10 snapshots per sort option
    
    init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    func saveRankSnapshot(songs: [Song], sortDescriptor: SortDescriptor) {
        let rankings = songs.enumerated().reduce(into: [String: Int]()) { result, item in
            result[item.element.id] = item.offset + 1
        }
        
        let newSnapshot = RankSnapshot(
            timestamp: Date(),
            sortDescriptor: sortDescriptor,
            rankings: rankings
        )
        
        // Get existing snapshots for this sort descriptor
        var snapshots = getStoredSnapshots(for: sortDescriptor)
        
        // Add new snapshot
        snapshots.append(newSnapshot)
        
        // Keep only the most recent snapshots (cleanup old data)
        if snapshots.count > maxSnapshotsPerSort {
            snapshots = Array(snapshots.suffix(maxSnapshotsPerSort))
            #if DEBUG
            logger.log("Cleaned up old snapshots, keeping last \(maxSnapshotsPerSort) for \(sortDescriptor.key)", level: .debug)
            #endif
        }
        
        // Save back to UserDefaults using centralized key management
        let key = UserDefaultsKeys.rankSnapshotsKey(for: sortDescriptor)
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: key)
        }
        
        #if DEBUG
        logger.log("Saved rank snapshot for \(sortDescriptor.key) with \(songs.count) songs (total snapshots: \(snapshots.count))", level: .debug)
        #endif
    }
    
    func getRankChanges(for songs: [Song], sortDescriptor: SortDescriptor) -> [String: RankChange] {
        let snapshots = getStoredSnapshots(for: sortDescriptor)
        
        guard let previousSnapshot = snapshots.last else {
            // No previous snapshots - don't show any indicators initially
            #if DEBUG
            logger.log("No previous snapshots found for \(sortDescriptor.key)", level: .debug)
            #endif
            return [:]
        }
        
        var changes: [String: RankChange] = [:]
        
        for (currentIndex, song) in songs.enumerated() {
            let currentRank = currentIndex + 1
            
            if let previousRank = previousSnapshot.rankings[song.id] {
                if previousRank < currentRank {
                    changes[song.id] = .down(currentRank - previousRank)
                } else if previousRank > currentRank {
                    changes[song.id] = .up(previousRank - currentRank)
                } else {
                    changes[song.id] = .same
                }
            } else {
                changes[song.id] = .new
            }
        }
        
        #if DEBUG
        let significantChanges = changes.filter { _, change in
            switch change {
            case .up(let positions), .down(let positions): return positions > 3
            case .new: return true
            case .same: return false
            }
        }
        if !significantChanges.isEmpty {
            logger.log("Rank changes detected: \(significantChanges.count) significant changes from snapshot \(DateFormatter.localizedString(from: previousSnapshot.timestamp, dateStyle: .none, timeStyle: .short))", level: .debug)
        } else {
            logger.log("Computed rank changes for \(songs.count) songs from snapshot \(DateFormatter.localizedString(from: previousSnapshot.timestamp, dateStyle: .none, timeStyle: .short))", level: .debug)
        }
        #endif
        
        return changes
    }
    
    func cleanupOldSnapshots() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        let snapshotKeys = keys.filter { $0.hasPrefix("rankSnapshots_") }
        
        for key in snapshotKeys {
            guard let data = userDefaults.data(forKey: key),
                  let snapshots = try? JSONDecoder().decode([RankSnapshot].self, from: data) else {
                continue
            }
            
            // Remove snapshots older than 30 days
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            let recentSnapshots = snapshots.filter { $0.timestamp > thirtyDaysAgo }
            
            if recentSnapshots.count != snapshots.count {
                if let cleanData = try? JSONEncoder().encode(recentSnapshots) {
                    userDefaults.set(cleanData, forKey: key)
                }
                #if DEBUG
                logger.log("Cleaned up \(snapshots.count - recentSnapshots.count) old snapshots from \(key)", level: .debug)
                #endif
            }
        }
        
        // Update last cleanup timestamp using centralized key management
        userDefaults.set(Date().timeIntervalSince1970, forKey: UserDefaultsKeys.cacheLastCleanupDate)
    }
    
    func clearAllRankHistory() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove all rank history keys using the prefix pattern
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        
        for key in rankHistoryKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        logger.log("Cleared all rank history data: \(rankHistoryKeys.count) entries removed", level: .info)
    }
    
    private func getStoredSnapshots(for sortDescriptor: SortDescriptor) -> [RankSnapshot] {
        let key = UserDefaultsKeys.rankSnapshotsKey(for: sortDescriptor)
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshots = try? JSONDecoder().decode([RankSnapshot].self, from: data) else {
            return []
        }
        return snapshots
    }
    
    // MARK: - Additional Helper Methods for Cache Management
    
    func getRankHistoryCacheInfo() -> (entryCount: Int, totalSize: String) {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        
        var totalSize = 0
        for key in rankHistoryKeys {
            if let data = userDefaults.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: Int64(totalSize))
        
        return (entryCount: rankHistoryKeys.count, totalSize: sizeString)
    }
    
    func getSnapshotCount(for sortDescriptor: SortDescriptor) -> Int {
        return getStoredSnapshots(for: sortDescriptor).count
    }
    
    func getOldestSnapshotDate() -> Date? {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        
        var oldestDate: Date?
        
        for key in rankHistoryKeys {
            guard let data = userDefaults.data(forKey: key),
                  let snapshots = try? JSONDecoder().decode([RankSnapshot].self, from: data) else {
                continue
            }
            
            for snapshot in snapshots {
                if oldestDate == nil || snapshot.timestamp < oldestDate! {
                    oldestDate = snapshot.timestamp
                }
            }
        }
        
        return oldestDate
    }
    
    func getNewestSnapshotDate() -> Date? {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let rankHistoryKeys = allKeys.filter { $0.hasPrefix("rankSnapshots_") }
        
        var newestDate: Date?
        
        for key in rankHistoryKeys {
            guard let data = userDefaults.data(forKey: key),
                  let snapshots = try? JSONDecoder().decode([RankSnapshot].self, from: data) else {
                continue
            }
            
            for snapshot in snapshots {
                if newestDate == nil || snapshot.timestamp > newestDate! {
                    newestDate = snapshot.timestamp
                }
            }
        }
        
        return newestDate
    }
}
