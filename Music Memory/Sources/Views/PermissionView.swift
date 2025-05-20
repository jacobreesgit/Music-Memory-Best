import SwiftUI
import UIKit

struct PermissionRequestView: View {
    let onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(AppFonts.system(size: AppFontSize.icon))
                .foregroundColor(AppColors.primary)
            
            Title2Text(text: "Music Library Access")
                .fontWeight(AppFontWeight.bold)
            
            BodyText(text: "Music Memory needs access to your music library to show your songs sorted by play count.")
                .multilineTextAlignment(.center)
                .horizontalPadding(AppSpacing.extraLarge)
            
            Button("Allow Access", action: onRequest)
                .primaryStyle()
                .horizontalPadding(AppSpacing.extraLarge)
                .padding(.top, AppSpacing.medium)
            
            Spacer()
        }
    }
}

struct PermissionDeniedView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()
            
            Image(systemName: "exclamationmark.lock.fill")
                .font(AppFonts.system(size: AppFontSize.icon))
                .foregroundColor(AppColors.destructive)
            
            Title2Text(text: "Permission Denied")
                .fontWeight(AppFontWeight.bold)
            
            SubheadlineText(text: "Music Memory needs access to your music library. Please update your settings to allow access.")
                .multilineTextAlignment(.center)
                .horizontalPadding(AppSpacing.extraLarge)
            
            VStack(spacing: AppSpacing.small) {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                }
                .primaryStyle()
                
                Button("Try Again", action: onRetry)
                    .secondaryStyle()
            }
            .horizontalPadding(AppSpacing.extraLarge)
            .padding(.top, AppSpacing.medium)
            
            Spacer()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .opacity(0.7)
                .ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.5)
                .standardPadding()
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background)
                        .appShadow(AppShadow.small)
                )
        }
    }
}
