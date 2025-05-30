import Foundation
import MediaPlayer
import MusicKit
import Combine

protocol MusicLibraryServiceProtocol {
    func requestPermission() async -> Bool
    func fetchSongs() async throws -> [Song]
    func checkPermissionStatus() async -> AppPermissionStatus
}

actor MusicLibraryService: MusicLibraryServiceProtocol {
    private let permissionService: PermissionServiceProtocol
    private let logger: LoggerProtocol
    private var musicKitSearchCache: [String: MusicKit.Song] = [:]
    private var lastEnhancementTime: Date?
    private let enhancementCooldown: TimeInterval = 300 // 5 minutes between full enhancement runs
    
    init(permissionService: PermissionServiceProtocol, logger: LoggerProtocol) {
        self.permissionService = permissionService
        self.logger = logger
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
        
        logger.log("Fetching songs with MediaPlayer and MusicKit enhancement", level: .info)
        
        // Get MediaPlayer songs first (primary source)
        let mediaPlayerSongs = try await fetchMediaPlayerSongs()
        
        // Check if we should enhance with MusicKit
        let musicKitStatus = MusicAuthorization.currentStatus
        guard musicKitStatus == .authorized else {
            logger.log("MusicKit not authorized - returning MediaPlayer songs only", level: .info)
            return mediaPlayerSongs
        }
        
        // Check cooldown to prevent excessive API usage
        if let lastTime = lastEnhancementTime,
           Date().timeIntervalSince(lastTime) < enhancementCooldown {
            logger.log("Enhancement cooldown active - returning cached results", level: .info)
            return mediaPlayerSongs
        }
        
        // Enhance songs with MusicKit data
        let enhancedSongs = await enhanceSongsWithMusicKit(mediaPlayerSongs)
        lastEnhancementTime = Date()
        
        return enhancedSongs
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
        
        // Convert to Song objects without MusicKit data initially
        let songs = mediaItems.map { mediaItem in
            return Song(from: mediaItem, musicKitTrack: nil)
        }
        
        logger.log("Fetched \(songs.count) songs from MediaPlayer", level: .info)
        
        return songs
    }
    
    private func enhanceSongsWithMusicKit(_ songs: [Song]) async -> [Song] {
        logger.log("Starting MusicKit enhancement for \(songs.count) songs", level: .info)
        
        var enhancedSongs: [Song] = []
        var successCount = 0
        var failureCount = 0
        
        // Process songs in batches to respect API limits
        let batchSize = 25
        let batches = songs.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            logger.log("Processing batch \(batchIndex + 1)/\(batches.count) with \(batch.count) songs", level: .debug)
            
            // Process batch with rate limiting
            let batchResults = await processSongBatch(batch)
            enhancedSongs.append(contentsOf: batchResults.songs)
            successCount += batchResults.successCount
            failureCount += batchResults.failureCount
            
            // Rate limiting delay between batches (except for last batch)
            if batchIndex < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            }
        }
        
        let enhancementRate = successCount > 0 ? Double(successCount) / Double(songs.count) * 100 : 0
        logger.log("MusicKit enhancement completed: \(successCount)/\(songs.count) successful (\(String(format: "%.1f", enhancementRate))%)", level: .info)
        
        return enhancedSongs
    }
    
    private func processSongBatch(_ songs: [Song]) async -> (songs: [Song], successCount: Int, failureCount: Int) {
        var enhancedSongs: [Song] = []
        var successCount = 0
        var failureCount = 0
        
        // Create search requests for the batch
        let searchTasks = songs.map { song in
            searchMusicKitSong(for: song)
        }
        
        // Execute searches concurrently
        let results = await withTaskGroup(of: (Song, MusicKit.Song?).self, returning: [(Song, MusicKit.Song?)].self) { group in
            for (index, task) in searchTasks.enumerated() {
                group.addTask {
                    let musicKitSong = await task
                    return (songs[index], musicKitSong)
                }
            }
            
            var results: [(Song, MusicKit.Song?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Create enhanced songs from results
        for (originalSong, musicKitSong) in results {
            let enhancedSong = Song(from: originalSong.mediaItem, musicKitTrack: musicKitSong)
            enhancedSongs.append(enhancedSong)
            
            if musicKitSong != nil {
                successCount += 1
            } else {
                failureCount += 1
            }
        }
        
        return (songs: enhancedSongs, successCount: successCount, failureCount: failureCount)
    }
    
    private func searchMusicKitSong(for song: Song) async -> MusicKit.Song? {
        // Check cache first
        let cacheKey = "\(song.title)_\(song.artist)".lowercased()
        if let cachedSong = musicKitSearchCache[cacheKey] {
            return cachedSong
        }
        
        do {
            // Create search request
            let searchTerm = "\(song.title) \(song.artist)"
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
            request.limit = 5 // Get top 5 results for better matching
            
            let response = try await request.response()
            
            // Find best match using intelligent matching algorithm
            if let bestMatch = findBestMatch(for: song, in: response.songs) {
                // Cache the result
                musicKitSearchCache[cacheKey] = bestMatch
                return bestMatch
            }
            
            return nil
            
        } catch {
            logger.log("MusicKit search failed for '\(song.title)' by '\(song.artist)': \(error.localizedDescription)", level: .debug)
            return nil
        }
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
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
