import Foundation
import MediaPlayer
import MusicKit
import Combine

protocol MusicLibraryServiceProtocol {
    func requestPermission() async -> Bool
    func fetchSongs() async throws -> [Song]
    func checkPermissionStatus() async -> AppPermissionStatus
    func enhanceSongWithMusicKit(_ song: Song) async -> Song?
    func enhanceSongsBatch(batchSize: Int) async -> [Song]
}

/// Cached MusicKit search result with better key management
struct CachedMusicKitResult: Codable {
    let searchTerm: String
    let timestamp: Date
    let version: Int
    let musicKitSongId: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let artworkURLString: String?
    let duration: TimeInterval?
    let releaseDate: Date?
    let genreNames: [String]
    let composerName: String?
    let trackNumber: Int?
    let isExplicit: Bool
    
    static let currentVersion = 1
}

/// Metadata for tracking MusicKit search cache with validation
struct MusicKitSearchMetadata: Codable {
    let searchKey: String
    let timestamp: Date
    let dataSize: Int
    let originalSearchTerm: String
}

actor MusicLibraryService: MusicLibraryServiceProtocol {
    private let permissionService: PermissionServiceProtocol
    private let logger: LoggerProtocol
    private let priorityService: EnhancementPriorityServiceProtocol
    private let enhancedSongCacheService: EnhancedSongCacheServiceProtocol
    private let artworkPersistenceService: ArtworkPersistenceServiceProtocol
    private let userDefaults = UserDefaults.standard
    private let searchCacheMaxAge: TimeInterval = 14 * 24 * 60 * 60 // 14 days
    private let maxCachedSearches = 1000 // Higher limit with better cleanup
    private var lastEnhancementTime: Date?
    private let enhancementCooldown: TimeInterval = 300 // 5 minutes between full enhancement runs
    
    init(
        permissionService: PermissionServiceProtocol,
        logger: LoggerProtocol,
        priorityService: EnhancementPriorityServiceProtocol,
        enhancedSongCacheService: EnhancedSongCacheServiceProtocol,
        artworkPersistenceService: ArtworkPersistenceServiceProtocol
    ) {
        self.permissionService = permissionService
        self.logger = logger
        self.priorityService = priorityService
        self.enhancedSongCacheService = enhancedSongCacheService
        self.artworkPersistenceService = artworkPersistenceService
    }
    
    func requestPermission() async -> Bool {
        // Request both MediaPlayer and MusicKit permissions
        let mediaPlayerGranted = await permissionService.requestMusicLibraryPermission()
        let musicKitGranted = await requestMusicKitPermission()
        
        // MediaPlayer permission is required, MusicKit is enhancement
        if mediaPlayerGranted {
            if !musicKitGranted {
                logger.log("MusicKit permission not granted - will use MediaPlayer only", level: .info)
            } else {
                logger.log("Both MediaPlayer and MusicKit permissions granted", level: .info)
            }
            return true
        }
        
        return false
    }
    
    func checkPermissionStatus() async -> AppPermissionStatus {
        return await permissionService.checkMusicLibraryPermissionStatus()
    }
    
    func fetchSongs() async throws -> [Song] {
        guard await permissionService.checkMusicLibraryPermissionStatus() == .granted else {
            throw AppError.permissionDenied
        }
        
        logger.log("Fetching songs from MediaPlayer with cache integration", level: .info)
        
        // Fetch MediaPlayer songs
        let mediaPlayerSongs = try await fetchMediaPlayerSongs()
        
        // Check cache for each song and merge if available
        var songsWithCache: [Song] = []
        
        for mediaPlayerSong in mediaPlayerSongs {
            // Try to get cached enhanced version first
            if let cachedSong = enhancedSongCacheService.getCachedEnhancedSong(for: mediaPlayerSong.id, mediaItem: mediaPlayerSong.mediaItem) {
                songsWithCache.append(cachedSong)
                logger.log("Using cached enhanced data for '\(mediaPlayerSong.title)'", level: .debug)
            } else {
                // Use MediaPlayer version
                songsWithCache.append(mediaPlayerSong)
            }
        }
        
        logger.log("Fetched \(songsWithCache.count) songs (\(songsWithCache.filter { enhancedSongCacheService.isSongEnhanced($0.id) }.count) from cache)", level: .info)
        
        return songsWithCache
    }
    
    // New method for priority-based batch enhancement with proper caching
    func enhanceSongsBatch(batchSize: Int = 10) async -> [Song] {
        // Get next priority batch from the priority service
        let songsToEnhance = priorityService.getNextBatchForEnhancement(batchSize: batchSize)
        
        guard !songsToEnhance.isEmpty else {
            return []
        }
        
        var enhancedSongs: [Song] = []
        
        for song in songsToEnhance {
            // Skip if already enhanced and cached
            if enhancedSongCacheService.isSongEnhanced(song.id) {
                logger.log("Song '\(song.title)' already enhanced and cached - skipping", level: .debug)
                priorityService.markSongAsEnhanced(song.id)
                continue
            }
            
            if let enhancedSong = await enhanceSongWithMusicKit(song) {
                enhancedSongs.append(enhancedSong)
                
                // CRITICAL FIX: Actually cache the enhanced song
                enhancedSongCacheService.cacheEnhancedSong(enhancedSong)
                
                // CRITICAL FIX: Cache the enhanced artwork if available
                if let enhancedArtwork = enhancedSong.enhancedArtwork {
                    await cacheEnhancedArtwork(enhancedSong, enhancedArtwork: enhancedArtwork)
                }
                
                priorityService.markSongAsEnhanced(song.id)
            } else {
                // Mark as processed even if enhancement failed
                priorityService.markSongAsEnhanced(song.id)
            }
            
            // Small delay between songs to prevent overwhelming the system
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
        }
        
        logger.log("Enhanced and cached batch: \(enhancedSongs.count)/\(songsToEnhance.count) successful", level: .debug)
        return enhancedSongs
    }
    
    // Individual song enhancement method with proper caching integration
    func enhanceSongWithMusicKit(_ song: Song) async -> Song? {
        // Check if already cached first
        if enhancedSongCacheService.isSongEnhanced(song.id) {
            logger.log("Song '\(song.title)' already enhanced and cached", level: .debug)
            return enhancedSongCacheService.getCachedEnhancedSong(for: song.id, mediaItem: song.mediaItem)
        }
        
        // Check if MusicKit is available
        guard MusicAuthorization.currentStatus == .authorized else {
            logger.log("MusicKit not authorized - cannot enhance song '\(song.title)'", level: .debug)
            return nil
        }
        
        // Search for the song in MusicKit
        if let musicKitSong = await searchMusicKitSong(for: song) {
            // Create enhanced version of the song
            let enhancedSong = Song(from: song.mediaItem, musicKitTrack: musicKitSong)
            
            // CRITICAL FIX: Cache the enhanced song immediately
            enhancedSongCacheService.cacheEnhancedSong(enhancedSong)
            
            // CRITICAL FIX: Cache the enhanced artwork
            if let enhancedArtwork = enhancedSong.enhancedArtwork {
                await cacheEnhancedArtwork(enhancedSong, enhancedArtwork: enhancedArtwork)
            }
            
            logger.log("Enhanced and cached song '\(song.title)' with MusicKit data", level: .debug)
            return enhancedSong
        }
        
        return nil
    }
    
    // CRITICAL FIX: New method to coordinate artwork caching
    private func cacheEnhancedArtwork(_ song: Song, enhancedArtwork: Artwork) async {
        do {
            // Get high-quality artwork URL
            if let artworkURL = enhancedArtwork.url(width: 300, height: 300) {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                if let artworkImage = UIImage(data: data) {
                    // Cache artwork using persistence service
                    await MainActor.run {
                        artworkPersistenceService.saveCurrentArtwork(songId: song.id, artwork: artworkImage)
                    }
                    logger.log("Cached enhanced artwork for '\(song.title)'", level: .debug)
                }
            }
        } catch {
            logger.log("Failed to cache enhanced artwork for '\(song.title)': \(error.localizedDescription)", level: .debug)
        }
    }
    
    // MARK: - Cache Management with Proper Validation
    
    func clearMusicKitSearchCache() {
        let metadata = getMusicKitSearchMetadata()
        
        for item in metadata {
            let key = UserDefaultsKeys.musicKitSearchKey(for: item.originalSearchTerm)
            userDefaults.removeObject(forKey: key)
        }
        
        userDefaults.removeObject(forKey: UserDefaultsKeys.musicKitSearchMetadata)
        
        logger.log("Cleared MusicKit search cache: \(metadata.count) entries removed", level: .info)
    }
    
    func cleanupOldMusicKitSearchCache() {
        var metadata = getMusicKitSearchMetadata()
        let oldEntries = metadata.filter { Date().timeIntervalSince($0.timestamp) > searchCacheMaxAge }
        
        // Remove old cache entries
        for entry in oldEntries {
            let key = UserDefaultsKeys.musicKitSearchKey(for: entry.originalSearchTerm)
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove old entries from metadata
        metadata.removeAll { oldEntries.contains($0) }
        
        // Validate remaining cache entries
        let (validMetadata, corruptedEntries) = validateSearchCacheEntries(metadata)
        
        // Remove corrupted entries
        for entry in corruptedEntries {
            let key = UserDefaultsKeys.musicKitSearchKey(for: entry.originalSearchTerm)
            userDefaults.removeObject(forKey: key)
        }
        
        metadata = validMetadata
        
        // If we have too many cached searches, remove oldest ones
        if metadata.count > maxCachedSearches {
            let sortedMetadata = metadata.sorted { $0.timestamp < $1.timestamp }
            let toRemove = sortedMetadata.prefix(metadata.count - maxCachedSearches)
            
            for entry in toRemove {
                let key = UserDefaultsKeys.musicKitSearchKey(for: entry.originalSearchTerm)
                userDefaults.removeObject(forKey: key)
            }
            
            metadata = Array(sortedMetadata.suffix(maxCachedSearches))
        }
        
        // Save updated metadata
        saveMusicKitSearchMetadata(metadata)
        
        let totalRemoved = oldEntries.count + corruptedEntries.count
        if totalRemoved > 0 {
            logger.log("Cleaned up \(totalRemoved) MusicKit search cache entries (\(oldEntries.count) old, \(corruptedEntries.count) corrupted)", level: .debug)
        }
    }
    
    // MARK: - Private Methods
    
    private func requestMusicKitPermission() async -> Bool {
        let status = await MusicAuthorization.request()
        let granted = status == .authorized
        logger.log("MusicKit permission status: \(status)", level: .info)
        return granted
    }
    
    private func fetchMediaPlayerSongs() async throws -> [Song] {
        // Create a query to get all songs
        let songsQuery = MPMediaQuery.songs()
        
        guard let mediaItems = songsQuery.items else {
            logger.log("No media items found", level: .warning)
            throw AppError.noMediaItemsFound
        }
        
        logger.log("Found \(mediaItems.count) total media items before filtering", level: .info)
        
        // Filter out uploaded songs
        let localLibrarySongs = mediaItems.filter { mediaItem in
            let isUploaded = isUploadedSong(mediaItem)
            
            if isUploaded {
                logger.log("Skipping uploaded song: '\(mediaItem.title ?? "Unknown")' by '\(mediaItem.artist ?? "Unknown")'", level: .debug)
            }
            
            return !isUploaded
        }
        
        logger.log("Filtered to \(localLibrarySongs.count) local library songs (skipped \(mediaItems.count - localLibrarySongs.count) uploaded songs)", level: .info)
        
        // Convert to Song objects without MusicKit data initially
        let songs = localLibrarySongs.map { mediaItem in
            return Song(from: mediaItem, musicKitTrack: nil)
        }
        
        logger.log("Fetched \(songs.count) songs from MediaPlayer (excluding uploaded songs)", level: .info)
        
        return songs
    }
    
    // MARK: - Uploaded Song Detection
    
    private func isUploadedSong(_ mediaItem: MPMediaItem) -> Bool {
        // Use only verified MediaPlayer properties that exist
        let isCloudItem = mediaItem.value(forProperty: MPMediaItemPropertyIsCloudItem) as? Bool ?? false
        let hasProtectedAsset = mediaItem.value(forProperty: MPMediaItemPropertyHasProtectedAsset) as? Bool ?? false
        let assetURL = mediaItem.value(forProperty: MPMediaItemPropertyAssetURL) as? URL
        
        // Simple but effective detection logic:
        // Uploaded songs are typically cloud items without DRM protection
        let isPotentialUpload = isCloudItem && !hasProtectedAsset
        
        // Additional check: Local file URLs often indicate user uploads
        let hasLocalFileURL = assetURL?.scheme == "file"
        
        // Enhanced detection: Cloud items with local file URLs are very likely uploads
        let isLikelyUpload = isCloudItem && hasLocalFileURL
        
        let isUploadedSong = isPotentialUpload || isLikelyUpload
        
        if isUploadedSong {
            logger.log("Detected uploaded song '\(mediaItem.title ?? "Unknown")': CloudItem=\(isCloudItem), Protected=\(hasProtectedAsset), AssetURL=\(assetURL?.absoluteString ?? "nil")", level: .debug)
        }
        
        return isUploadedSong
    }
    
    // MARK: - MusicKit Search and Matching with Improved Caching
    
    private func searchMusicKitSong(for song: Song) async -> MusicKit.Song? {
        let searchTerm = "\(song.title) \(song.artist)"
        let searchKey = createSearchKey(for: searchTerm)
        
        // Check cache first with proper validation
        if let cachedResult = getCachedMusicKitResult(for: searchTerm, searchKey: searchKey) {
            // Try to convert cached result back to MusicKit.Song
            return await convertCachedResultToMusicKitSong(cachedResult)
        }
        
        do {
            // Create search request
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
            request.limit = 5 // Get top 5 results for better matching
            
            let response = try await request.response()
            
            // Find best match using intelligent matching algorithm
            if let bestMatch = findBestMatch(for: song, in: response.songs) {
                // Cache the result with proper key management
                cacheMusicKitResult(searchTerm: searchTerm, searchKey: searchKey, musicKitSong: bestMatch)
                return bestMatch
            }
            
            return nil
            
        } catch {
            logger.log("MusicKit search failed for '\(song.title)' by '\(song.artist)': \(error.localizedDescription)", level: .debug)
            return nil
        }
    }
    
    // CRITICAL FIX: Better search key generation to avoid collisions
    private func createSearchKey(for searchTerm: String) -> String {
        let normalized = searchTerm
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        // Add hash to avoid collisions
        let hash = searchTerm.hash
        return "\(normalized)_\(hash)"
    }
    
    private func getCachedMusicKitResult(for searchTerm: String, searchKey: String) -> CachedMusicKitResult? {
        let key = UserDefaultsKeys.musicKitSearchKey(for: searchTerm)
        
        guard let data = userDefaults.data(forKey: key),
              let cachedResult = try? JSONDecoder().decode(CachedMusicKitResult.self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid
        if !isSearchCacheValid(cachedResult) {
            // Remove expired cache
            userDefaults.removeObject(forKey: key)
            removeFromMusicKitSearchMetadata(searchKey: searchKey)
            logger.log("Removed expired search cache for: '\(searchTerm)'", level: .debug)
            return nil
        }
        
        logger.log("Retrieved cached MusicKit search result for: '\(searchTerm)'", level: .debug)
        return cachedResult
    }
    
    private func isSearchCacheValid(_ cachedResult: CachedMusicKitResult) -> Bool {
        // Check age
        if Date().timeIntervalSince(cachedResult.timestamp) > searchCacheMaxAge {
            return false
        }
        
        // Check version
        if cachedResult.version != CachedMusicKitResult.currentVersion {
            return false
        }
        
        return true
    }
    
    private func cacheMusicKitResult(searchTerm: String, searchKey: String, musicKitSong: MusicKit.Song) {
        let cachedResult = CachedMusicKitResult(
            searchTerm: searchTerm,
            timestamp: Date(),
            version: CachedMusicKitResult.currentVersion,
            musicKitSongId: musicKitSong.id.rawValue,
            title: musicKitSong.title,
            artistName: musicKitSong.artistName,
            albumTitle: musicKitSong.albumTitle,
            artworkURLString: musicKitSong.artwork?.url(width: 300, height: 300)?.absoluteString,
            duration: musicKitSong.duration,
            releaseDate: musicKitSong.releaseDate,
            genreNames: musicKitSong.genreNames,
            composerName: musicKitSong.composerName,
            trackNumber: musicKitSong.trackNumber,
            isExplicit: musicKitSong.contentRating == .explicit
        )
        
        do {
            let data = try JSONEncoder().encode(cachedResult)
            let key = UserDefaultsKeys.musicKitSearchKey(for: searchTerm)
            userDefaults.set(data, forKey: key)
            
            // Update metadata with better tracking
            updateMusicKitSearchMetadata(searchKey: searchKey, originalSearchTerm: searchTerm, dataSize: data.count)
            
            logger.log("Cached MusicKit search result for: '\(searchTerm)' (\(data.count) bytes)", level: .debug)
        } catch {
            logger.log("Failed to cache MusicKit search result: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func convertCachedResultToMusicKitSong(_ cachedResult: CachedMusicKitResult) async -> MusicKit.Song? {
        // Try to get the song by ID from MusicKit
        do {
            let songId = MusicItemID(cachedResult.musicKitSongId)
            var request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: songId)
            let response = try await request.response()
            
            if let song = response.items.first {
                logger.log("Successfully reconstructed MusicKit song from cache: '\(song.title)'", level: .debug)
                return song
            }
        } catch {
            logger.log("Failed to recreate MusicKit song from cache: \(error.localizedDescription)", level: .debug)
        }
        
        return nil
    }
    
    private func findBestMatch(for song: Song, in results: MusicItemCollection<MusicKit.Song>) -> MusicKit.Song? {
        guard !results.isEmpty else { return nil }
        
        var bestMatch: MusicKit.Song?
        var bestScore: Double = 0.0
        let minimumScore: Double = 0.7 // Require at least 70% similarity
        
        for candidate in results {
            let score = calculateSimilarityScore(
                originalTitle: song.title,
                originalArtist: song.artist,
                candidateTitle: candidate.title,
                candidateArtist: candidate.artistName
            )
            
            if score > bestScore && score >= minimumScore {
                bestScore = score
                bestMatch = candidate
            }
        }
        
        if let match = bestMatch {
            logger.log("Found MusicKit match for '\(song.title)' -> '\(match.title)' (score: \(String(format: "%.2f", bestScore)))", level: .debug)
        }
        
        return bestMatch
    }
    
    private func calculateSimilarityScore(originalTitle: String, originalArtist: String, candidateTitle: String, candidateArtist: String) -> Double {
        // Normalize strings for comparison
        let normalizedOriginalTitle = normalizeForComparison(originalTitle)
        let normalizedOriginalArtist = normalizeForComparison(originalArtist)
        let normalizedCandidateTitle = normalizeForComparison(candidateTitle)
        let normalizedCandidateArtist = normalizeForComparison(candidateArtist)
        
        // Calculate title similarity (weighted 60%)
        let titleSimilarity = stringSimilarity(normalizedOriginalTitle, normalizedCandidateTitle)
        
        // Calculate artist similarity (weighted 40%)
        let artistSimilarity = stringSimilarity(normalizedOriginalArtist, normalizedCandidateArtist)
        
        // Combined score
        let score = titleSimilarity * 0.6 + artistSimilarity * 0.4
        
        return score
    }
    
    private func normalizeForComparison(_ string: String) -> String {
        return string
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        // Use Levenshtein distance for similarity calculation
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        
        if maxLength == 0 {
            return 1.0
        }
        
        return 1.0 - Double(distance) / Double(maxLength)
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        let m = s1.count
        let n = s2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if s1[i-1] == s2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    // MARK: - MusicKit Search Metadata Management with Validation
    
    private func validateSearchCacheEntries(_ metadata: [MusicKitSearchMetadata]) -> (valid: [MusicKitSearchMetadata], corrupted: [MusicKitSearchMetadata]) {
        var valid: [MusicKitSearchMetadata] = []
        var corrupted: [MusicKitSearchMetadata] = []
        
        for entry in metadata {
            let key = UserDefaultsKeys.musicKitSearchKey(for: entry.originalSearchTerm)
            
            guard let data = userDefaults.data(forKey: key) else {
                corrupted.append(entry)
                continue
            }
            
            guard let cached = try? JSONDecoder().decode(CachedMusicKitResult.self, from: data) else {
                corrupted.append(entry)
                continue
            }
            
            if isSearchCacheValid(cached) {
                valid.append(entry)
            } else {
                corrupted.append(entry)
            }
        }
        
        return (valid: valid, corrupted: corrupted)
    }
    
    private func updateMusicKitSearchMetadata(searchKey: String, originalSearchTerm: String, dataSize: Int) {
        var metadata = getMusicKitSearchMetadata()
        
        // Remove existing entry if present
        metadata.removeAll { $0.searchKey == searchKey }
        
        // Add new entry
        metadata.append(MusicKitSearchMetadata(
            searchKey: searchKey,
            timestamp: Date(),
            dataSize: dataSize,
            originalSearchTerm: originalSearchTerm
        ))
        
        saveMusicKitSearchMetadata(metadata)
    }
    
    private func removeFromMusicKitSearchMetadata(searchKey: String) {
        var metadata = getMusicKitSearchMetadata()
        metadata.removeAll { $0.searchKey == searchKey }
        saveMusicKitSearchMetadata(metadata)
    }
    
    private func getMusicKitSearchMetadata() -> [MusicKitSearchMetadata] {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.musicKitSearchMetadata),
              let metadata = try? JSONDecoder().decode([MusicKitSearchMetadata].self, from: data) else {
            return []
        }
        return metadata
    }
    
    private func saveMusicKitSearchMetadata(_ metadata: [MusicKitSearchMetadata]) {
        do {
            let data = try JSONEncoder().encode(metadata)
            userDefaults.set(data, forKey: UserDefaultsKeys.musicKitSearchMetadata)
        } catch {
            logger.log("Failed to save MusicKit search metadata: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - Comparable conformance for metadata sorting

extension MusicKitSearchMetadata: Comparable {
    static func < (lhs: MusicKitSearchMetadata, rhs: MusicKitSearchMetadata) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
    
    static func == (lhs: MusicKitSearchMetadata, rhs: MusicKitSearchMetadata) -> Bool {
        lhs.searchKey == rhs.searchKey
    }
}
