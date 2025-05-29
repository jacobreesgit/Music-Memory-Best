import SwiftUI
import UIKit

// MARK: - Colors
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
    
    // Added standard colors
    static let white = Color.white
    static let black = Color.black
    static let clear = Color.clear
    
    // Additional semantic colors
    static let destructive = Color.red
    static let inactive = Color(.systemGray3)
    static let divider = Color(.separator)
}

// MARK: - Typography
enum AppFonts {
    static let title = Font.title
    static let title2 = Font.title2
    static let title3 = Font.title3
    static let headline = Font.headline
    static let subheadline = Font.subheadline
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption
    static let caption2 = Font.caption2
    
    // Dynamic font sizes
    static func system(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight)
    }
}

enum AppFontWeight {
    static let regular = Font.Weight.regular
    static let medium = Font.Weight.medium
    static let semibold = Font.Weight.semibold
    static let bold = Font.Weight.bold
}

enum AppFontSize {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    static let huge: CGFloat = 48  // For the play count number
    static let icon: CGFloat = 64  // For large icons
}

// MARK: - Spacing & Layout
enum AppSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    static let huge: CGFloat = 48
    
    enum Horizontal {
        static let tiny = EdgeInsets(top: 0, leading: AppSpacing.tiny, bottom: 0, trailing: AppSpacing.tiny)
        static let small = EdgeInsets(top: 0, leading: AppSpacing.small, bottom: 0, trailing: AppSpacing.small)
        static let medium = EdgeInsets(top: 0, leading: AppSpacing.medium, bottom: 0, trailing: AppSpacing.medium)
        static let large = EdgeInsets(top: 0, leading: AppSpacing.large, bottom: 0, trailing: AppSpacing.large)
        static let extraLarge = EdgeInsets(top: 0, leading: AppSpacing.extraLarge, bottom: 0, trailing: AppSpacing.extraLarge)
    }
    
    enum Vertical {
        static let tiny = EdgeInsets(top: AppSpacing.tiny, leading: 0, bottom: AppSpacing.tiny, trailing: 0)
        static let small = EdgeInsets(top: AppSpacing.small, leading: 0, bottom: AppSpacing.small, trailing: 0)
        static let medium = EdgeInsets(top: AppSpacing.medium, leading: 0, bottom: AppSpacing.medium, trailing: 0)
        static let large = EdgeInsets(top: AppSpacing.large, leading: 0, bottom: AppSpacing.large, trailing: 0)
        static let extraLarge = EdgeInsets(top: AppSpacing.extraLarge, leading: 0, bottom: AppSpacing.extraLarge, trailing: 0)
    }
}

// MARK: - Corner Radius
enum AppRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let extraLarge: CGFloat = 16
    static let circular: CGFloat = 999
}

// MARK: - Shadows
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct AppShadow {
    static let small = Shadow(
        color: Color.black.opacity(0.1),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let medium = Shadow(
        color: Color.black.opacity(0.15),
        radius: 8,
        x: 0,
        y: 4
    )
    
    static let large = Shadow(
        color: Color.black.opacity(0.2),
        radius: 16,
        x: 0,
        y: 8
    )
}

// MARK: - Haptic Feedback
enum AppHaptics {
    /// Success haptic - for successful actions like navigation, completion
    static func success() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    /// Error haptic - for failed actions, restrictions, errors
    static func error() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
    }
    
    /// Warning haptic - for warnings, cautions, blocked actions
    static func warning() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
    }
    
    /// Light impact - for subtle interactions, previews, hover states
    static func lightImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    /// Medium impact - for standard interactions, button presses, selections
    static func mediumImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }
    
    /// Heavy impact - for significant interactions, important actions
    static func heavyImpact() {
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()
    }
    
    /// Selection changed - for picker changes, selection feedback
    static func selectionChanged() {
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }
}

// MARK: - View Extensions
extension View {
    // Apply shadow from the design system
    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    // Apply standard padding based on design system
    func standardPadding() -> some View {
        self.padding(AppSpacing.medium)
    }
    
    // Apply horizontal padding based on design system
    func horizontalPadding(_ spacing: CGFloat = AppSpacing.medium) -> some View {
        self.padding(.horizontal, spacing)
    }
    
    // Apply vertical padding based on design system
    func verticalPadding(_ spacing: CGFloat = AppSpacing.medium) -> some View {
        self.padding(.vertical, spacing)
    }
}

// MARK: - Card Component
struct AppCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(AppSpacing.medium)
            .background(AppColors.white)
            .cornerRadius(AppRadius.large)
            .appShadow(AppShadow.small)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.headline)
            .foregroundColor(AppColors.white)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium)
            .background(AppColors.primary)
            .cornerRadius(AppRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .appShadow(AppShadow.small)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    AppHaptics.lightImpact()
                }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.headline)
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium)
            .background(AppColors.secondaryBackground)
            .cornerRadius(AppRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    AppHaptics.lightImpact()
                }
            }
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.headline)
            .foregroundColor(AppColors.white)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium)
            .background(AppColors.destructive)
            .cornerRadius(AppRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    AppHaptics.mediumImpact()
                }
            }
    }
}

extension Button {
    func primaryStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func destructiveStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }
}

// MARK: - Text Styles
struct TitleText: View {
    let text: String
    var weight: Font.Weight = .regular
    
    var body: some View {
        Text(text)
            .font(AppFonts.title)
            .fontWeight(weight)
            .foregroundColor(AppColors.primaryText)
    }
}

struct Title2Text: View {
    let text: String
    var weight: Font.Weight = .regular
    
    var body: some View {
        Text(text)
            .font(AppFonts.title2)
            .fontWeight(weight)
            .foregroundColor(AppColors.primaryText)
    }
}

struct HeadlineText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(AppFonts.headline)
            .foregroundColor(AppColors.primaryText)
    }
}

struct SubheadlineText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(AppFonts.subheadline)
            .foregroundColor(AppColors.secondaryText)
    }
}

struct BodyText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(AppFonts.body)
            .foregroundColor(AppColors.primaryText)
    }
}

struct CaptionText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(AppFonts.caption)
            .foregroundColor(AppColors.secondaryText)
    }
}
