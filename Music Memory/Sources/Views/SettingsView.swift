import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    // Header Section
                    VStack(spacing: AppSpacing.large) {
                        // App Icon and Title
                        VStack(spacing: AppSpacing.medium) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: AppFontSize.icon))
                                .foregroundColor(AppColors.primary)
                                .appShadow(AppShadow.small)
                            
                            TitleText(text: "Music Memory", weight: .bold)
                        }
                    }
                    .padding(AppSpacing.medium)
                    
                    // Settings Content
                    VStack(spacing: AppSpacing.large) {
                        AppCard {
                            VStack(spacing: AppSpacing.medium) {
                                // Card Header
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                        HeadlineText(text: "Local Data")
                                        CaptionText(text: "Storage: \(viewModel.localDataSize)")
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "internaldrive")
                                        .font(.title2)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                Divider()
                                
                                // Data Description
                                VStack(alignment: .leading, spacing: AppSpacing.large) {
                                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                                        InfoRow(
                                            icon: "shield.checkered",
                                            title: "Your Music is Safe",
                                            description: "Only local tracking data is cleared. Your system music library remains untouched."
                                        )
                                        
                                        InfoRow(
                                            icon: "arrow.clockwise",
                                            title: "Fresh Start",
                                            description: "Play count tracking and rank changes will start over from your current system values."
                                        )
                                        
                                        InfoRow(
                                            icon: "exclamationmark.triangle",
                                            title: "Cannot be Undone",
                                            description: "This action permanently removes all local tracking history."
                                        )
                                    }
                                    
                                    // Clear Data Button
                                    Button(action: {
                                        viewModel.showClearDataConfirmation()
                                    }) {
                                        HStack(spacing: AppSpacing.small) {
                                            if viewModel.isClearing {
                                                ProgressView()
                                                    .scaleEffect(0.9)
                                                    .tint(AppColors.white)
                                            } else {
                                                Image(systemName: "trash")
                                            }
                                            
                                            Text(viewModel.isClearing ? "Clearing Data..." : "Clear All Local Data")
                                        }
                                    }
                                    .destructiveStyle()
                                    .disabled(viewModel.isClearing)
                                    .opacity(viewModel.isClearing ? 0.7 : 1.0)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.extraLarge)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .background(AppColors.background.ignoresSafeArea())
            .alert("Clear All Local Data?", isPresented: $viewModel.showingClearDataAlert) {
                Button("Cancel", role: .cancel) {
                    // Cancel action - no haptic needed as user is backing out
                }
                
                Button("Clear All", role: .destructive) {
                    Task {
                        await viewModel.clearAllLocalData()
                    }
                }
            } message: {
                Text("This will permanently delete all local play count adjustments, rank change history, and saved artwork. This action cannot be undone.\n\nYour system music library will not be affected.")
            }
            .onAppear {
                // Recalculate data size when view appears
                viewModel.calculateDataSize()
            }
        }
    }
}

// MARK: - Supporting Views

struct DataItemRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppColors.primary)
                .frame(width: 16)
            
            Text(text)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: AppFontSize.medium))
                .foregroundColor(AppColors.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Text(title)
                    .font(AppFonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primaryText)
                
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
