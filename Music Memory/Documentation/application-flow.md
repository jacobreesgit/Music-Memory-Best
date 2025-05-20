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

## User Navigation

1. **Song List**: User sees a list of songs sorted by play count
   - Each row shows song title, artist, album, artwork, and play count
   - User can pull to refresh the list

2. **Song Details**: User taps a song to see detailed information
   - Shows larger artwork
   - Displays comprehensive song information
   - Shows play count in a prominent way

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

## Testing the App

1. **Unit Tests**: Run unit tests to verify core functionality
   - `MusicLibraryServiceTests`: Tests the music library service
   - `SongListViewModelTests`: Tests the song list view model

2. **Manual Testing Checklist**:
   - Verify permission flows work correctly
   - Check song listing and sorting
   - Confirm artwork loading
   - Test error scenarios
   - Verify UI in both light and dark mode
   - Test with different accessibility settings
