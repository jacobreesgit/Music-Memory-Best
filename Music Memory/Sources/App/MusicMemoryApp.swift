import SwiftUI

@main
struct MusicMemoryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = DIContainer.production()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.appState as! AppState)
                .environmentObject(container.navigationManager)
                .environmentObject(container.appLifecycleManager)
        }
    }
}
