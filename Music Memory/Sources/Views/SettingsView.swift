import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingDetailedCacheInfo = false
    @State private var showingCacheRecommendations = false
    
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
                        // Local Data Management Card
                        AppCard {
                            VStack(spacing: AppSpacing.medium) {
                                // Card Header
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                        HeadlineText(text: "Local Data Management")
                                        CaptionText(text: "Total Storage: \(viewModel.localDataSize)")
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "internaldrive")
                                        .font(.title2)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                Divider()
                                
                                // Cache Information Section
                                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                    // Quick Cache Overview
                                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                                        HStack {
                                            InfoRow(
                                                icon: "shield.checkered",
                                                title: "Your Music is Safe",
                                                description: "Only local tracking data is cleared. Your system music library remains untouched."
                                            )
                                        }
                                        
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
                                    
                                    // Cache Details and Actions
                                    HStack(spacing: AppSpacing.small) {
                                        Button(action: {
                                            showingDetailedCacheInfo = true
                                        }) {
                                            HStack(spacing: AppSpacing.tiny) {
                                                Image(systemName: "info.circle")
                                                Text("Cache Details")
                                            }
                                        }
                                        .secondaryStyle()
                                        
                                        Button(action: {
                                            showingCacheRecommendations = true
                                        }) {
                                            HStack(spacing: AppSpacing.tiny) {
                                                Image(systemName: "lightbulb")
                                                Text("Optimize")
                                            }
                                        }
                                        .secondaryStyle()
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
                        
                        // Additional Settings Cards can go here in the future
                        // For example: Privacy settings, Export data, etc.
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
                Text("This will permanently delete all local play count adjustments, rank change history, enhanced song data, cached artwork, and search cache. This action cannot be undone.\n\nYour system music library will not be affected.")
            }
            .sheet(isPresented: $showingDetailedCacheInfo) {
                CacheDetailView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingCacheRecommendations) {
                CacheRecommendationsView(viewModel: viewModel)
            }
            .onAppear {
                // Recalculate data size when view appears
                viewModel.calculateDataSize()
            }
        }
    }
}

// MARK: - Cache Detail View

struct CacheDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var cacheInfo: CacheInfo?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    if let cacheInfo = cacheInfo {
                        // Total Size Header
                        AppCard {
                            VStack(spacing: AppSpacing.small) {
                                HeadlineText(text: "Total Cache Size")
                                Text(cacheInfo.totalSize)
                                    .font(.system(size: AppFontSize.extraLarge, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        
                        // Breakdown by Type
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Storage Breakdown")
                                
                                ForEach(cacheInfo.breakdown, id: \.name) { item in
                                    CacheBreakdownRow(name: item.name, size: item.size)
                                }
                            }
                        }
                        
                        // Cache Information
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Cache Information")
                                
                                VStack(alignment: .leading, spacing: AppSpacing.small) {
                                    InfoRow(
                                        icon: "info.circle",
                                        title: "Play Count Tracking",
                                        description: "Stores local play count adjustments and baseline counts for accurate tracking."
                                    )
                                    
                                    InfoRow(
                                        icon: "chart.line.uptrend.xyaxis",
                                        title: "Rank History",
                                        description: "Maintains snapshots of song rankings to show movement indicators."
                                    )
                                    
                                    InfoRow(
                                        icon: "sparkles",
                                        title: "Enhanced Song Data",
                                        description: "Caches enhanced metadata from MusicKit for richer song information."
                                    )
                                    
                                    InfoRow(
                                        icon: "photo",
                                        title: "Artwork Cache",
                                        description: "Stores high-quality artwork images for faster loading."
                                    )
                                    
                                    InfoRow(
                                        icon: "magnifyingglass",
                                        title: "Search Cache",
                                        description: "Caches MusicKit search results to avoid redundant API calls."
                                    )
                                }
                            }
                        }
                    } else {
                        // Loading State
                        AppCard {
                            VStack(spacing: AppSpacing.medium) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(AppColors.primary)
                                
                                Text("Loading cache details...")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(AppSpacing.large)
                        }
                    }
                }
                .padding(AppSpacing.medium)
            }
            .navigationTitle("Cache Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCacheInfo()
            }
        }
    }
    
    private func loadCacheInfo() {
        Task {
            let info = viewModel.getDetailedCacheInfo()
            
            await MainActor.run {
                self.cacheInfo = info
            }
        }
    }
}

// MARK: - Cache Recommendations View

struct CacheRecommendationsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var recommendations: [String] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    if isLoading {
                        AppCard {
                            VStack(spacing: AppSpacing.medium) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(AppColors.primary)
                                
                                Text("Analyzing cache...")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(AppSpacing.large)
                        }
                    } else {
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Cache Optimization")
                                
                                if recommendations.isEmpty {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.success)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Cache is Optimized")
                                                .font(AppFonts.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(AppColors.primaryText)
                                            
                                            Text("Your cache is healthy and doesn't need optimization.")
                                                .font(AppFonts.caption)
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                        
                                        Spacer()
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                                        ForEach(recommendations, id: \.self) { recommendation in
                                            HStack(alignment: .top) {
                                                Image(systemName: "lightbulb.fill")
                                                    .foregroundColor(AppColors.warning)
                                                    .font(.caption)
                                                    .padding(.top, 2)
                                                
                                                Text(recommendation)
                                                    .font(AppFonts.body)
                                                    .foregroundColor(AppColors.primaryText)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Quick Actions
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Quick Actions")
                                
                                VStack(spacing: AppSpacing.small) {
                                    Button(action: {
                                        // Trigger cache refresh
                                        viewModel.calculateDataSize()
                                        loadRecommendations()
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Refresh Analysis")
                                            Spacer()
                                        }
                                    }
                                    .secondaryStyle()
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.medium)
            }
            .navigationTitle("Optimization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRecommendations()
            }
        }
    }
    
    private func loadRecommendations() {
        isLoading = true
        
        Task {
            // Simulate analysis time
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Get cache management service recommendations
            let recs = DIContainer.shared.cacheManagementService.getCacheOptimizationRecommendations()
            
            await MainActor.run {
                self.recommendations = recs
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views

struct CacheBreakdownRow: View {
    let name: String
    let size: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Text(size)
                .font(AppFonts.body)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

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
