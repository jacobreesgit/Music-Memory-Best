import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingDetailedCacheInfo = false
    @State private var showingCacheRecommendations = false
    @State private var showingCacheIntegrityReport = false
    
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
                        // CRITICAL FIX: Enhanced Cache Health Card
                        AppCard {
                            VStack(spacing: AppSpacing.medium) {
                                // Card Header with Health Indicator
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                        HStack {
                                            HeadlineText(text: "Cache System")
                                            
                                            Spacer()
                                            
                                            // Health indicator
                                            HStack(spacing: AppSpacing.tiny) {
                                                Circle()
                                                    .fill(viewModel.cacheHealthColor)
                                                    .frame(width: 8, height: 8)
                                                
                                                Text(viewModel.cacheHealthSummary)
                                                    .font(AppFonts.caption)
                                                    .foregroundColor(viewModel.cacheHealthColor)
                                            }
                                        }
                                        
                                        CaptionText(text: "Total Storage: \(viewModel.localDataSize)")
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "internaldrive")
                                        .font(.title2)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                // CRITICAL FIX: Cache warning if there are problems
                                if viewModel.shouldShowCacheWarning {
                                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                                        Divider()
                                        
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(AppColors.warning)
                                            
                                            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                                                Text("Cache Issues Detected")
                                                    .font(AppFonts.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(AppColors.warning)
                                                
                                                if let report = viewModel.getCacheIntegrityReport() {
                                                    Text(report.problemSummary)
                                                        .font(AppFonts.caption)
                                                        .foregroundColor(AppColors.secondaryText)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                    }
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
                                    
                                    // CRITICAL FIX: Enhanced Cache Actions
                                    VStack(spacing: AppSpacing.small) {
                                        // Cache management buttons
                                        HStack(spacing: AppSpacing.small) {
                                            Button(action: {
                                                showingDetailedCacheInfo = true
                                            }) {
                                                HStack(spacing: AppSpacing.tiny) {
                                                    Image(systemName: "info.circle")
                                                    Text("Details")
                                                }
                                            }
                                            .secondaryStyle()
                                            
                                            Button(action: {
                                                showingCacheIntegrityReport = true
                                            }) {
                                                HStack(spacing: AppSpacing.tiny) {
                                                    Image(systemName: "checkmark.shield")
                                                    Text("Health")
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
                                        
                                        // Refresh cache validation button
                                        Button(action: {
                                            AppHaptics.lightImpact()
                                            viewModel.refreshCacheValidation()
                                        }) {
                                            HStack(spacing: AppSpacing.small) {
                                                if viewModel.isValidatingCache {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .tint(AppColors.primary)
                                                } else {
                                                    Image(systemName: "arrow.clockwise")
                                                }
                                                
                                                Text(viewModel.isValidatingCache ? "Validating..." : "Refresh Cache Status")
                                            }
                                        }
                                        .secondaryStyle()
                                        .disabled(viewModel.isValidatingCache)
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
            .sheet(isPresented: $showingCacheIntegrityReport) {
                CacheIntegrityReportView(viewModel: viewModel)
            }
            .onAppear {
                // Recalculate data size and validate cache when view appears
                viewModel.calculateDataSize()
                viewModel.validateCacheIntegrity()
            }
        }
    }
}

// MARK: - Cache Detail View (Updated)

struct CacheDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var cacheBreakdown: CacheBreakdown?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    if let breakdown = cacheBreakdown {
                        // Total Size Header
                        AppCard {
                            VStack(spacing: AppSpacing.small) {
                                HeadlineText(text: "Total Cache Size")
                                Text(breakdown.totalSize)
                                    .font(.system(size: AppFontSize.extraLarge, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        
                        // Enhanced Breakdown by Type with Entry Counts
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Storage Breakdown")
                                
                                ForEach(breakdown.breakdown, id: \.name) { item in
                                    CacheBreakdownRow(
                                        name: item.name,
                                        size: item.size,
                                        entries: item.entries
                                    )
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
                loadCacheBreakdown()
            }
        }
    }
    
    private func loadCacheBreakdown() {
        Task {
            let breakdown = await Task.detached {
                return viewModel.getDetailedCacheInfo()
            }.value
            
            await MainActor.run {
                self.cacheBreakdown = breakdown
            }
        }
    }
}

// CRITICAL FIX: Cache Integrity Report View
struct CacheIntegrityReportView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var integrityReport: CacheIntegrityReport?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    if let report = integrityReport {
                        // Health Score Header
                        AppCard {
                            VStack(spacing: AppSpacing.small) {
                                HStack {
                                    Circle()
                                        .fill(healthColor(for: report.healthScore))
                                        .frame(width: 16, height: 16)
                                    
                                    HeadlineText(text: "Cache Integrity")
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1f%%", report.healthScore * 100))
                                        .font(AppFonts.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(healthColor(for: report.healthScore))
                                }
                                
                                Text(report.problemSummary)
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Integrity Details
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Cache Validation Results")
                                
                                VStack(alignment: .leading, spacing: AppSpacing.small) {
                                    IntegrityRow(label: "Total Entries", value: "\(report.totalEntries)")
                                    IntegrityRow(label: "Valid Entries", value: "\(report.validEntries)", color: AppColors.success)
                                    
                                    if report.staleEntries > 0 {
                                        IntegrityRow(label: "Stale Entries", value: "\(report.staleEntries)", color: AppColors.warning)
                                    }
                                    
                                    if report.corruptedEntries > 0 {
                                        IntegrityRow(label: "Corrupted Entries", value: "\(report.corruptedEntries)", color: AppColors.destructive)
                                    }
                                    
                                    if report.orphanedKeys > 0 {
                                        IntegrityRow(label: "Orphaned Keys", value: "\(report.orphanedKeys)", color: AppColors.warning)
                                    }
                                }
                            }
                        }
                        
                        // Detailed Breakdown
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                HeadlineText(text: "Detailed Breakdown")
                                
                                VStack(alignment: .leading, spacing: AppSpacing.small) {
                                    CacheTypeIntegrityRow(
                                        title: "Enhanced Songs",
                                        integrity: report.enhancedSongIntegrity
                                    )
                                    
                                    CacheTypeIntegrityRow(
                                        title: "Artwork Cache",
                                        integrity: report.artworkIntegrity
                                    )
                                    
                                    CacheTypeIntegrityRow(
                                        title: "Search Cache",
                                        integrity: report.searchIntegrity
                                    )
                                }
                            }
                        }
                        
                        // Recommendations
                        if !report.recommendations.isEmpty {
                            AppCard {
                                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                    HeadlineText(text: "Recommendations")
                                    
                                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                                        ForEach(report.recommendations, id: \.self) { recommendation in
                                            HStack(alignment: .top) {
                                                Image(systemName: report.hasProblems ? "exclamationmark.triangle" : "checkmark.circle")
                                                    .foregroundColor(report.hasProblems ? AppColors.warning : AppColors.success)
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
                    } else {
                        // Loading State
                        AppCard {
                            VStack(spacing: AppSpacing.medium) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(AppColors.primary)
                                
                                Text("Validating cache integrity...")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(AppSpacing.large)
                        }
                    }
                }
                .padding(AppSpacing.medium)
            }
            .navigationTitle("Cache Integrity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadIntegrityReport()
            }
        }
    }
    
    private func healthColor(for score: Double) -> Color {
        if score >= 0.8 {
            return AppColors.success
        } else if score >= 0.5 {
            return AppColors.warning
        } else {
            return AppColors.destructive
        }
    }
    
    private func loadIntegrityReport() {
        integrityReport = viewModel.getCacheIntegrityReport()
    }
}

// MARK: - Cache Recommendations View (Updated)

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
                                        viewModel.refreshCacheValidation()
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
            
            // Get recommendations from cache integrity report
            let recs = viewModel.getCacheIntegrityReport()?.recommendations ?? []
            
            await MainActor.run {
                self.recommendations = recs
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views (Updated)

struct CacheBreakdownRow: View {
    let name: String
    let size: String
    let entries: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                Text(name)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Text("\(entries) entries")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(size)
                .font(AppFonts.body)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

struct IntegrityRow: View {
    let label: String
    let value: String
    var color: Color = AppColors.primaryText
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.body)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct CacheTypeIntegrityRow: View {
    let title: String
    let integrity: (valid: Int, stale: Int, corrupted: Int)
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
            Text(title)
                .font(AppFonts.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primaryText)
            
            HStack(spacing: AppSpacing.medium) {
                if integrity.valid > 0 {
                    Label("\(integrity.valid)", systemImage: "checkmark.circle.fill")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.success)
                }
                
                if integrity.stale > 0 {
                    Label("\(integrity.stale)", systemImage: "clock.fill")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.warning)
                }
                
                if integrity.corrupted > 0 {
                    Label("\(integrity.corrupted)", systemImage: "xmark.circle.fill")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.destructive)
                }
                
                Spacer()
            }
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
