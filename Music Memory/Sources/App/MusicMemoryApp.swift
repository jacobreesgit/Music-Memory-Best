import SwiftUI

@main
struct MusicMemoryApp: App {
    @StateObject private var container = DIContainer.production()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.appState as! AppState)
                .environmentObject(container.navigationManager)
        }
    }
}
