import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DIContainer
    @StateObject private var navigationManager = NavigationManager()
    
    var body: some View {
        TabBarView()
            .environmentObject(navigationManager)
    }
}
