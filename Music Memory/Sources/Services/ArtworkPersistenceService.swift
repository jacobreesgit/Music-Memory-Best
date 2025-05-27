import Foundation
import UIKit
import MediaPlayer

protocol ArtworkPersistenceServiceProtocol {
    func saveCurrentArtwork(songId: String, artwork: UIImage?)
    func loadSavedArtwork(for songId: String) -> UIImage?
    func clearSavedArtwork()
    func cleanupOldArtwork()
}

class ArtworkPersistenceService: ArtworkPersistenceServiceProtocol {
    private let logger: LoggerProtocol
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let savedSongIdKey = "savedArtworkSongId"
    private let savedTimestampKey = "savedArtworkTimestamp"
    private let artworkMaxAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    func saveCurrentArtwork(songId: String, artwork: UIImage?) {
        guard let artwork = artwork else {
            logger.log("No artwork to save for song ID: \(songId)", level: .debug)
            return
        }
        
        logger.log("Saving artwork for song ID: \(songId)", level: .info)
        
        // Convert image to data with reasonable compression
        guard let imageData = artwork.jpegData(compressionQuality: 0.8) else {
            logger.log("Failed to convert artwork to data for song ID: \(songId)", level: .error)
            return
        }
        
        // Save to Documents directory for better performance than UserDefaults for image data
        let fileName = "saved_artwork_\(songId).jpg"
        guard let documentsPath = getDocumentsDirectory() else {
            logger.log("Failed to get documents directory", level: .error)
            return
        }
        
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: filePath)
            
            // Save metadata to UserDefaults
            userDefaults.set(songId, forKey: savedSongIdKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: savedTimestampKey)
            
            logger.log("Successfully saved artwork for song ID: \(songId) to \(fileName)", level: .info)
        } catch {
            logger.log("Failed to save artwork file: \(error.localizedDescription)", level: .error)
        }
    }
    
    func loadSavedArtwork(for songId: String) -> UIImage? {
        // Check if we have saved artwork for this song
        guard let savedSongId = userDefaults.string(forKey: savedSongIdKey),
              savedSongId == songId else {
            logger.log("No saved artwork found for song ID: \(songId)", level: .debug)
            return nil
        }
        
        // Check if the saved artwork is not too old
        let savedTimestamp = userDefaults.double(forKey: savedTimestampKey)
        let age = Date().timeIntervalSince1970 - savedTimestamp
        
        if age > artworkMaxAge {
            logger.log("Saved artwork is too old (\(Int(age / 3600)) hours), clearing it", level: .info)
            clearSavedArtwork()
            return nil
        }
        
        // Load the artwork file
        let fileName = "saved_artwork_\(songId).jpg"
        guard let documentsPath = getDocumentsDirectory() else {
            logger.log("Failed to get documents directory", level: .error)
            return nil
        }
        
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        guard let imageData = try? Data(contentsOf: filePath),
              let image = UIImage(data: imageData) else {
            logger.log("Failed to load saved artwork from file for song ID: \(songId)", level: .warning)
            clearSavedArtwork()
            return nil
        }
        
        logger.log("Successfully loaded saved artwork for song ID: \(songId)", level: .info)
        return image
    }
    
    func clearSavedArtwork() {
        // Get the saved song ID to know which file to delete
        if let savedSongId = userDefaults.string(forKey: savedSongIdKey) {
            let fileName = "saved_artwork_\(savedSongId).jpg"
            guard let documentsPath = getDocumentsDirectory() else { return }
            let filePath = documentsPath.appendingPathComponent(fileName)
            
            try? FileManager.default.removeItem(at: filePath)
            logger.log("Cleared saved artwork file for song ID: \(savedSongId)", level: .debug)
        }
        
        // Clear metadata
        userDefaults.removeObject(forKey: savedSongIdKey)
        userDefaults.removeObject(forKey: savedTimestampKey)
        
        logger.log("Cleared saved artwork metadata", level: .debug)
    }
    
    func cleanupOldArtwork() {
        // Clean up any old artwork files that might be left over
        guard let documentsPath = getDocumentsDirectory() else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
            let artworkFiles = files.filter { $0.lastPathComponent.hasPrefix("saved_artwork_") }
            
            for file in artworkFiles {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date {
                    let age = Date().timeIntervalSince(creationDate)
                    if age > artworkMaxAge {
                        try? FileManager.default.removeItem(at: file)
                        logger.log("Cleaned up old artwork file: \(file.lastPathComponent)", level: .debug)
                    }
                }
            }
        } catch {
            logger.log("Failed to cleanup old artwork files: \(error.localizedDescription)", level: .warning)
        }
    }
    
    private func getDocumentsDirectory() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
}
