import SwiftUI
import MusicKit
import MediaPlayer

struct ContentView: View {
    @StateObject private var setupManager = SetupManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Music Memory")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Text("Personal Billboard Hot 100 Charts")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if setupManager.isSetupComplete {
                // Setup complete - show main interface
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Setup Complete!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(setupManager.getDataSourceDescription())
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Features:")
                            .font(.headline)
                        
                        ForEach(setupManager.getAvailableFeatures(), id: \.self) { feature in
                            HStack {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                                Text(feature)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            } else {
                // Setup in progress
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text(setupManager.setupStatus)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    
                    if !setupManager.hasAppleMusic && !setupManager.hasMediaLibraryAccess {
                        Text("Music Memory needs access to your music library to create personalized charts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .onAppear {
            setupApp()
        }
    }
    
    private func setupApp() {
        Task {
            await setupManager.performSetup()
        }
    }
}

#Preview {
    ContentView()
}