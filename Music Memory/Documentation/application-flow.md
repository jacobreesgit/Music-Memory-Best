# Music Memory App - Application Flow & Usage

## Initial Launch Flow

1. **Startup**: App launches and initializes the dependency container
2. **Permission Check**: App checks for music library permission status
3. **User Flow**:
   - If permission is not determined → Show permission request screen
   - If permission is denied → Show permission denied screen with guidance
   - If permission is granted → Proceed to loading songs

## Song Loading Process

1. `SongListViewModel` triggers `loadSongs()` which:
   - Sets the loading state
   - Checks permission status
   - Requests songs from the music library service
   - Handles any errors that occur
   - Updates the UI state

2. `MusicLibraryService.fetchSongs()`:
   - Checks if songs are cached
   - If cached, returns immediately
   - If not cached, queries the MPMediaLibrary
   - Transforms MPMediaItems into Song models
   - Sorts songs by play count
   - Caches the result
   - Returns the sorted songs

## Navigation System

1. **NavigationManager**: The app uses a centralized navigation manager that:
   - Maintains NavigationPath objects for different navigation flows
   - Provides methods to navigate to specific screens 
   - Handles programmatic navigation (push, pop, popToRoot)
   - Persists navigation state across app lifecycle events

2. **Navigation Implementation**:
   - Uses SwiftUI's NavigationStack with NavigationPath for type-safe navigation
   - Employs navigationDestination modifiers for different destination types
   - Supports deep linking and complex navigation patterns
   - Preserves navigation state during state restoration

## User Navigation

1. **Song List**: User sees a list of songs sorted by play count
   - Each row shows song title, artist, album, artwork, and play count
   - User taps a song to navigate to the song details screen
   - User can pull to refresh the list

2. **Song Details**: User taps a song to see detailed information
   - Shows larger artwork
   - Displays comprehensive song information
   - Shows play count in a prominent way
   - Provides toolbar actions for additional functionality

## Error Handling Flow

1. When an error occurs:
   - The error is captured as an `AppError`
   - The error is posted via `NotificationCenter`
   - The `AppState` captures the error
   - An alert is shown to the user with:
     - Error description
     - Recovery suggestion (if available)
     - Dismiss action

2. For permission-specific errors:
   - User is guided to Settings app
   - App provides a clear explanation of what permission is needed and why

## Memory Management

1. **Image Loading**:
   - Artwork is loaded at appropriate sizes for each context
   - Images are not held longer than needed

2. **Caching**:
   - The song list is cached to avoid repeated system API calls
   - Cache is invalidated when necessary (app returns to foreground)
