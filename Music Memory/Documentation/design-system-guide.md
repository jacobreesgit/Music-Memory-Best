# Music Memory Design System Guide

## Introduction

This design system guide provides a standardized framework for maintaining visual and functional consistency throughout the Music Memory application. It serves as a reference for all team members to ensure that UI components, colors, typography, spacing, and haptic feedback remain consistent across all parts of the application.

## Table of Contents

1. [Colors](#colors)
2. [Typography](#typography)
3. [Spacing & Layout](#spacing--layout)
4. [Corner Radius](#corner-radius)
5. [Shadows](#shadows)
6. [Haptic Feedback](#haptic-feedback)
7. [Components](#components)
   - [Buttons](#buttons)
   - [Text Components](#text-components)
   - [Media Components](#media-components)
8. [Usage Guidelines](#usage-guidelines)
9. [Implementation Examples](#implementation-examples)

## Colors

### Base Colors

| Name | Value | Description | Usage |
|------|-------|-------------|-------|
| `primary` | `Color.accentColor` | The app's main accent color | Primary buttons, active state indicators |
| `secondary` | `Color(.systemGray)` | Secondary accent color | Secondary elements, inactive states |
| `background` | `Color(.systemBackground)` | Primary background color | Screen backgrounds, content areas |
| `secondaryBackground` | `Color(.systemGray6)` | Secondary background | Secondary areas |

### Text Colors

| Name | Value | Description | Usage |
|------|-------|-------------|-------|
| `primaryText` | `Color(.label)` | Primary text color | Main text content |
| `secondaryText` | `Color(.secondaryLabel)` | Secondary text color | Labels, captions, hints |
| `tertiaryText` | `Color(.tertiaryLabel)` | Tertiary text color | Less important text |

### Functional Colors

| Name | Value | Description | Usage |
|------|-------|-------------|-------|
| `error` | `Color.red` | Error color | Error messages, alerts |
| `success` | `Color.green` | Success color | Success messages, confirmations |
| `warning` | `Color.yellow` | Warning color | Warning messages, alerts |
| `destructive` | `Color.red` | Destructive action | Delete buttons, destructive actions |
| `inactive` | `Color(.systemGray3)` | Inactive state | Disabled items, inactive state |
| `divider` | `Color(.separator)` | Divider color | Line separators, dividers |

### Color Usage Guidelines

- Use `primary` color sparingly to emphasize key actions
- Maintain proper contrast between text and backgrounds
- Respect the system's light/dark mode settings
- Use functional colors consistently for their designated purposes

## Typography

### Font Styles and Scales

SwiftUI provides a built-in font size system with scales that adapt to the user's preferred settings. Understanding the relationship between these scales is important for consistent typography:

| Name | Value | Scale Relationship | Usage |
|------|-------|-------------------|-------|
| `title` | `Font.title` | Largest standard text scale | Main headings, screen titles |
| `title2` | `Font.title2` | ~20% smaller than title | Secondary headings |
| `title3` | `Font.title3` | ~20% smaller than title2 | Tertiary headings |
| `headline` | `Font.headline` | Similar to body but bold | Bold subheadings |
| `subheadline` | `Font.subheadline` | ~15% smaller than body | Section headers |
| `body` | `Font.body` | Base text size | Main text content |
| `callout` | `Font.callout` | Similar to body with different weight | Callout text, emphasized points |
| `detail` | `Font.system(size: 14)` | 20% smaller than body | Captions, smaller text, secondary info |
| `caption` | `Font.caption` | ~30% smaller than body | Captions, smaller text |
| `caption2` | `Font.caption2` | Smallest text scale | Footnotes, fine print |

> **Note:** The exact size relationships between these fonts will vary slightly based on the user's Dynamic Type settings. Always use the semantic font names rather than explicit point sizes to ensure proper scaling.

### Font Weights

| Name | Value | Usage |
|------|-------|-------|
| `regular` | `Font.Weight.regular` | Standard text |
| `medium` | `Font.Weight.medium` | Slightly emphasized text |
| `semibold` | `Font.Weight.semibold` | Moderately emphasized text |
| `bold` | `Font.Weight.bold` | Strongly emphasized text |

### Font Sizes

| Name | Value | Usage |
|------|-------|-------|
| `small` | `12` | Small text, captions |
| `detail` | `14` | Detail text, 20% smaller than body |
| `medium` | `16` | Standard text, body |
| `large` | `24` | Headings, important text |
| `extraLarge` | `32` | Major headings |
| `huge` | `48` | Hero text, play count |
| `icon` | `64` | Large icons |

### Typography Usage Guidelines

- Always use the predefined text styles for consistency
- Respect the system's dynamic type settings
- Maintain proper hierarchy with font sizes and weights
- Use appropriate text styles for different content types
- Use `detail` font for secondary information like artist names, play counts, and status indicators

## Spacing & Layout

### Basic Spacing

| Name | Value | Usage |
|------|-------|-------|
| `tiny` | `4` | Minimal spacing, tight layouts |
| `small` | `8` | Compact spacing between related items |
| `medium` | `16` | Standard spacing between elements |
| `large` | `24` | Generous spacing between content sections |
| `extraLarge` | `32` | Major section separations |
| `huge` | `48` | Very large spacing for important elements |

### Horizontal Padding

| Name | Value | Description |
|------|-------|-------------|
| `tiny` | `EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)` | Minimal horizontal padding |
| `small` | `EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)` | Compact horizontal padding |
| `medium` | `EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)` | Standard horizontal padding |
| `large` | `EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)` | Generous horizontal padding |
| `extraLarge` | `EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32)` | Maximum horizontal padding |

### Vertical Padding

| Name | Value | Description |
|------|-------|-------------|
| `tiny` | `EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)` | Minimal vertical padding |
| `small` | `EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)` | Compact vertical padding |
| `medium` | `EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)` | Standard vertical padding |
| `large` | `EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0)` | Generous vertical padding |
| `extraLarge` | `EdgeInsets(top: 32, leading: 0, bottom: 32, trailing: 0)` | Maximum vertical padding |

### Spacing Usage Guidelines

- Use consistent spacing throughout the application
- Apply appropriate padding for different screen sizes
- Use vertical spacing to create visual hierarchy
- Maintain consistent spacing between similar elements

## Corner Radius

| Name | Value | Usage |
|------|-------|-------|
| `small` | `4` | Small elements, minor rounding |
| `medium` | `8` | Standard elements, buttons |
| `large` | `12` | Larger elements |
| `extraLarge` | `16` | Major elements, modal sheets |
| `circular` | `999` | Perfectly circular elements |

## Shadows

| Name | Properties | Usage |
|------|------------|-------|
| `small` | `color: black.opacity(0.1), radius: 4, x: 0, y: 2` | Subtle elevation, buttons |
| `medium` | `color: black.opacity(0.15), radius: 8, x: 0, y: 4` | Moderate elevation, popovers |
| `large` | `color: black.opacity(0.2), radius: 16, x: 0, y: 8` | Significant elevation, modals |

## Haptic Feedback

### Feedback Types

| Name | UIKit Type | Description | Usage |
|------|------------|-------------|-------|
| `success()` | `UINotificationFeedbackGenerator(.success)` | Positive confirmation | Successful actions, navigation, completion |
| `error()` | `UINotificationFeedbackGenerator(.error)` | Negative feedback | Failed actions, errors, restrictions |
| `warning()` | `UINotificationFeedbackGenerator(.warning)` | Cautionary feedback | Warnings, blocked actions, alerts |
| `lightImpact()` | `UIImpactFeedbackGenerator(.light)` | Subtle interaction | Minor interactions, previews, hover states |
| `mediumImpact()` | `UIImpactFeedbackGenerator(.medium)` | Standard interaction | Button presses, selections, important actions |
| `heavyImpact()` | `UIImpactFeedbackGenerator(.heavy)` | Strong interaction | Significant actions, confirmations |
| `selectionChanged()` | `UISelectionFeedbackGenerator()` | Selection feedback | Picker changes, list selections |

### Haptic Usage Guidelines

#### When to Use Each Type

**Success Haptics:**
- Navigation completed successfully
- Form submission succeeded
- Operation completed
- Permission granted

**Error Haptics:**
- Action blocked or failed
- Permission denied
- Invalid input
- Already in target state

**Warning Haptics:**
- Potentially destructive action
- Temporary unavailability
- Rate limiting
- Approaching limits

**Impact Haptics:**
- Light: Secondary buttons, subtle interactions
- Medium: Primary buttons, important selections
- Heavy: Destructive actions, major confirmations

**Selection Haptics:**
- Segmented control changes
- Picker wheel selections
- Tab switching
- Filter changes

#### Haptic Design Principles

1. **Consistency**: Use the same haptic for the same type of action across the app
2. **Semantic Meaning**: Match haptic intensity to action importance
3. **User Control**: Respect accessibility settings that disable haptics
4. **Restraint**: Don't overuse haptics - they should enhance, not overwhelm
5. **Context Awareness**: Consider the user's environment and device state

### Haptic Implementation Examples

```swift
// Successful navigation
AppHaptics.success()
navigationManager.navigateToSongDetail(song: song)

// Blocked action
if !canPerformAction {
    AppHaptics.error()
    return
}

// Button interaction
Button("Play Song") {
    AppHaptics.mediumImpact()
    playSong()
}

// Destructive action
Button("Delete Playlist") {
    AppHaptics.heavyImpact()
    deletePlaylist()
}
```

## Components

### Buttons

#### Primary Button
- Background: `AppColors.primary`
- Text Color: `AppColors.white`
- Font: `AppFonts.headline`
- Padding: `AppSpacing.medium`
- Corner Radius: `AppRadius.medium`
- Shadow: `AppShadow.small`
- Haptic: `AppHaptics.lightImpact()` on press

#### Secondary Button
- Background: `AppColors.secondaryBackground`
- Text Color: `AppColors.primary`
- Font: `AppFonts.headline`
- Padding: `AppSpacing.medium`
- Corner Radius: `AppRadius.medium`
- Shadow: None
- Haptic: `AppHaptics.lightImpact()` on press

#### Destructive Button
- Background: `AppColors.destructive`
- Text Color: `AppColors.white`
- Font: `AppFonts.headline`
- Padding: `AppSpacing.medium`
- Corner Radius: `AppRadius.medium`
- Shadow: None
- Haptic: `AppHaptics.mediumImpact()` on press

### Text Components

#### Title Text
```swift
TitleText(text: "Your Title")
TitleText(text: "Bold Title", weight: .bold)
```

#### Headline Text
```swift
HeadlineText(text: "Your Headline")
```

#### Body Text
```swift
BodyText(text: "Your paragraph text goes here.")
```

#### Detail Text
```swift
DetailText(text: "Secondary information text")
```

#### Caption Text
```swift
CaptionText(text: "Small caption text")
```

### Media Components

#### Artwork View
```swift
ArtworkView(artwork: song.artwork, size: 50)
```

#### Play Count View
```swift
PlayCountView(count: song.playCount)
```

## Usage Guidelines

### General Guidelines

1. **Consistency**: Use the design system components consistently across the app
2. **Accessibility**: Ensure all UI elements are accessible with appropriate sizing
3. **Responsiveness**: Design components should adapt to different screen sizes
4. **Dark Mode**: All components should support both light and dark mode
5. **Haptic Feedback**: Provide appropriate tactile feedback for user interactions

### Specific Component Guidelines

1. **Buttons**:
   - Use primary buttons for main actions
   - Use secondary buttons for alternative actions
   - Use destructive buttons for potentially harmful actions
   - Always include appropriate haptic feedback

2. **Typography**:
   - Maintain a clear hierarchy with font sizes and weights
   - Use appropriate text styles for different content types
   - Respect system font settings
   - Use `detail` font for secondary information and smaller text

3. **Layout**:
   - Use consistent spacing throughout the application
   - Apply appropriate padding for different screen sizes
   - Follow the spacing guidelines for component relationships

4. **Haptic Feedback**:
   - Match haptic intensity to action importance
   - Use semantic haptic types (success, error, warning)
   - Be consistent across similar interactions
   - Test on actual devices, not simulator

## Implementation Examples

### Button Usage with Haptics

```swift
// Primary action button with success haptic
Button("Allow Access") {
    AppHaptics.success()
    onRequest()
}
.primaryStyle()
.horizontalPadding(AppSpacing.extraLarge)

// Secondary action button 
Button("Try Again") {
    AppHaptics.mediumImpact()
    onRetry()
}
.secondaryStyle()

// Destructive action button
Button("Delete") {
    AppHaptics.heavyImpact()
    onDelete()
}
.destructiveStyle()
```

### Interactive Component with Contextual Haptics

```swift
Button {
    if canNavigate {
        AppHaptics.success()
        navigateToDetail()
    } else {
        AppHaptics.error()
        // Show feedback that action is blocked
    }
} label: {
    SongRowView(song: song)
}
.onLongPressGesture {
    if isAvailable {
        AppHaptics.mediumImpact()
        showContextMenu()
    } else {
        AppHaptics.warning()
        showUnavailableMessage()
    }
}
```

### Text Component Usage

```swift
VStack(alignment: .leading, spacing: AppSpacing.small) {
    TitleText(text: "Song Title", weight: .bold)
    
    SubheadlineText(text: "Artist Name")
    
    DetailText(text: "Secondary information")
    
    CaptionText(text: "Album Name")
}
```

### Layout Example

```swift
VStack(spacing: AppSpacing.large) {
    // Header section
    HeaderView()
        .horizontalPadding(AppSpacing.large)
    
    // Content section
    ContentView()
        .standardPadding()
    
    // Footer section
    FooterView()
        .horizontalPadding(AppSpacing.medium)
}
.background(AppColors.background)
```

### Complex Interaction with Multiple Haptic States

```swift
// Now Playing Bar interaction example
struct NowPlayingBar: View {
    var body: some View {
        // ... UI code ...
        .onTapGesture {
            if shouldAllowNavigation {
                AppHaptics.success()
                navigateToSongDetail()
            } else {
                AppHaptics.error()
                // Already viewing this song's detail
            }
        }
        .onLongPressGesture { 
            AppHaptics.mediumImpact()
            // Long press began
        } onPressingChanged: { pressing in
            if pressing && shouldAllowNavigation {
                AppHaptics.lightImpact()
            }
        }
    }
}
```
