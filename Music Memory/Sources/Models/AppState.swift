import Foundation
import SwiftUI

enum AppPermissionStatus {
    case unknown
    case notRequested
    case requested
    case granted
    case denied
}

class AppState: AppStateProtocol {
    @Published var musicLibraryPermissionStatus: AppPermissionStatus = .unknown
    @Published var isLoading: Bool = false
    @Published var currentError: AppError?
    
    func setError(_ error: AppError?) {
        DispatchQueue.main.async {
            self.currentError = error
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }
}
