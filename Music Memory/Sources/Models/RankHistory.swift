import Foundation
import SwiftUI

struct SortDescriptor: Equatable, Codable {
    let option: SortOption
    let direction: SortDirection
    
    var key: String {
        "\(option.rawValue)_\(direction.rawValue)"
    }
}

struct RankSnapshot: Codable {
    let timestamp: Date
    let sortDescriptor: SortDescriptor
    let rankings: [String: Int] // songId -> rank (1-based)
}

enum RankChange: Equatable {
    case up(Int)
    case down(Int)
    case same
    case new
    
    var icon: String {
        switch self {
        case .up(_): return "arrow.up"
        case .down(_): return "arrow.down"
        case .same: return "minus"
        case .new: return "plus"
        }
    }
    
    var color: Color {
        switch self {
        case .up(_): return AppColors.success
        case .down(_): return AppColors.destructive
        case .same: return AppColors.secondaryText.opacity(0.6)
        case .new: return AppColors.primary
        }
    }
    
    var magnitude: Int? {
        switch self {
        case .up(let positions): return positions
        case .down(let positions): return positions
        case .same, .new: return nil
        }
    }
}

// Make SortOption and SortDirection Codable
extension SortOption: Codable {}
extension SortDirection: Codable {}
