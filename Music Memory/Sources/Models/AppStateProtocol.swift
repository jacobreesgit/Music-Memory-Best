import Foundation

protocol AppStateProtocol: ObservableObject {
    var musicLibraryPermissionStatus: AppPermissionStatus { get set }
    var isLoading: Bool { get set }
    var currentError: AppError? { get set }
    
    func setError(_ error: AppError?)
    func clearError()
}
