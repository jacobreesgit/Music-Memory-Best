import SwiftUI

enum AppColors {
    // Base colors
    static let primary = Color.accentColor
    static let secondary = Color(.systemGray)
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.systemGray6)
    
    // Text colors
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
    
    // Functional colors
    static let error = Color.red
    static let success = Color.green
    static let warning = Color.yellow
}

enum AppFonts {
    static let title = Font.title
    static let title2 = Font.title2
    static let headline = Font.headline
    static let subheadline = Font.subheadline
    static let body = Font.body
    static let caption = Font.caption
    static let caption2 = Font.caption2
}

enum AppSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
}

enum AppRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let extraLarge: CGFloat = 16
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct AppShadow {
    static let small: Shadow = Shadow(
        color: Color.black.opacity(0.1),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let medium: Shadow = Shadow(
        color: Color.black.opacity(0.15),
        radius: 8,
        x: 0,
        y: 4
    )
}
