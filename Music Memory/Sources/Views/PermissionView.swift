import SwiftUI
import UIKit

struct PermissionRequestView: View {
    let onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Music Library Access")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Music Memory needs access to your music library to show your songs sorted by play count.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button(action: onRequest) {
                Text("Allow Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
        }
    }
}

struct PermissionDeniedView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.lock.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Permission Denied")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Music Memory needs access to your music library. Please update your settings to allow access.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.7)
                .ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 5)
                )
        }
    }
}
