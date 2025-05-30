import Foundation
import CoreData

// MARK: - RecentPlay Entity
@objc(RecentPlay)
public class RecentPlay: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var songID: String
    @NSManaged public var albumID: String
    @NSManaged public var artistID: String
    @NSManaged public var timestamp: Date
    @NSManaged public var playDuration: TimeInterval
    @NSManaged public var completionPercentage: Double
    @NSManaged public var source: String
    @NSManaged public var sessionID: String
}

extension RecentPlay {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecentPlay> {
        return NSFetchRequest<RecentPlay>(entityName: "RecentPlay")
    }
}

// MARK: - DailyAggregate Entity
@objc(DailyAggregate)
public class DailyAggregate: NSManagedObject {
    @NSManaged public var entityID: String
    @NSManaged public var entityType: String
    @NSManaged public var date: Date
    @NSManaged public var playCount: Int32
    @NSManaged public var totalDuration: TimeInterval
    @NSManaged public var averageCompletion: Double
}

extension DailyAggregate {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyAggregate> {
        return NSFetchRequest<DailyAggregate>(entityName: "DailyAggregate")
    }
}

// MARK: - ChartSnapshot Entity
@objc(ChartSnapshot)
public class ChartSnapshot: NSManagedObject {
    @NSManaged public var entityID: String
    @NSManaged public var entityType: String
    @NSManaged public var weekOf: Date
    @NSManaged public var position: Int32
    @NSManaged public var playsThisWeek: Int32
    @NSManaged public var movement: Int32
    @NSManaged public var movementType: String
}

extension ChartSnapshot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChartSnapshot> {
        return NSFetchRequest<ChartSnapshot>(entityName: "ChartSnapshot")
    }
}

// MARK: - SongMetadata Entity
@objc(SongMetadata)
public class SongMetadata: NSManagedObject {
    @NSManaged public var songID: String
    @NSManaged public var title: String
    @NSManaged public var artist: String
    @NSManaged public var album: String
    @NSManaged public var albumID: String
    @NSManaged public var artistID: String
    @NSManaged public var artworkURL: String?
    @NSManaged public var duration: TimeInterval
    @NSManaged public var releaseDate: Date?
}

extension SongMetadata {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongMetadata> {
        return NSFetchRequest<SongMetadata>(entityName: "SongMetadata")
    }
}

// MARK: - AlbumMetadata Entity
@objc(AlbumMetadata)
public class AlbumMetadata: NSManagedObject {
    @NSManaged public var albumID: String
    @NSManaged public var title: String
    @NSManaged public var artist: String
    @NSManaged public var artistID: String
    @NSManaged public var artworkURL: String?
    @NSManaged public var trackCount: Int32
    @NSManaged public var releaseDate: Date?
}

extension AlbumMetadata {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlbumMetadata> {
        return NSFetchRequest<AlbumMetadata>(entityName: "AlbumMetadata")
    }
}

// MARK: - ArtistMetadata Entity
@objc(ArtistMetadata)
public class ArtistMetadata: NSManagedObject {
    @NSManaged public var artistID: String
    @NSManaged public var name: String
    @NSManaged public var imageURL: String?
    @NSManaged public var genres: [String]
}

extension ArtistMetadata {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ArtistMetadata> {
        return NSFetchRequest<ArtistMetadata>(entityName: "ArtistMetadata")
    }
}

// MARK: - Chart Movement Enum
enum ChartMovement: String, CaseIterable {
    case up = "up"
    case down = "down"
    case same = "same"
    case new = "new"
    case reentry = "reentry"
}