# Music Memory iOS App - Stage 1 Development Documentation

## Project Overview
**Music Memory** is an iOS 18 Swift app that tracks users' music listening history to generate personalized Billboard Hot 100-style charts for songs, albums, AND artists. This stage focuses on establishing the core foundation: data architecture, music integration, and basic app structure.

## Current State: FOUNDATION COMPLETE ✅

### What Has Been Implemented

#### 1. Complete Core Data Architecture
- **Unlimited detail storage** - Every song completion stored forever
- **Smart query optimization** - Performance layers without data loss
- **Three-entity tracking** - Songs, Albums, and Artists all tracked
- **Real-time updates** - Charts update after every song completion

#### 2. Music Integration & Tracking
- **MusicKit integration** - Apple Music API access
- **MediaPlayer framework** - Local library access
- **Dual tracking system** - System + local play counts for immediate UI updates
- **Song ending detection** - Monitors playback position every 0.5 seconds
- **Natural completion detection** - Only counts songs played >50% to completion
- **Session management** - Groups plays by listening sessions

#### 3. App Structure & Permissions
- **SwiftUI interface** - Modern iOS 18 UI implementation
- **Permission handling** - MusicKit and MediaPlayer authorization
- **Graceful degradation** - Works with limited permissions
- **Setup flow** - Guided initialization process

## Files Created (All Complete)

### Core Application Files
1. **MusicMemoryApp.swift** - App entry point with Core Data integration
2. **ContentView.swift** - Main interface with setup flow and status display
3. **SetupManager.swift** - App initialization and permission management

### Data Layer
4. **CoreDataModels.swift** - All entity models (RecentPlay, DailyAggregate, ChartSnapshot, SongMetadata, AlbumMetadata, ArtistMetadata)
5. **PersistenceController.swift** - Core Data stack with optimization for large datasets
6. **DataManager.swift** - Smart query strategy and data operations
7. **MusicMemory.xcdatamodeld** - Core Data model definition

### Music Integration
8. **MusicManager.swift** - Complete MusicKit/MediaPlayer integration with playback monitoring

## Key Architecture Decisions

### Database Design
- **RecentPlays Table**: Stores EVERY song completion with unlimited retention
- **DailyAggregates**: Performance optimization layer (calculated from RecentPlays)
- **ChartSnapshots**: Weekly chart positions for movement tracking
- **Metadata Tables**: Separate entities for songs, albums, and artists
- **Smart Querying**: Uses RecentPlays for detail (0-30 days), aggregates for performance (30+ days)

### Tracking Strategy
- **Position Monitoring**: Timer checks playback every 0.5 seconds
- **Completion Detection**: Song must reach within 5 seconds of end AND >50% completion
- **Multi-Entity Recording**: Each play updates song, album, AND artist counts
- **Session Grouping**: 30-minute timeout creates new listening sessions

### Permission Model
- **MusicKit**: For Apple Music streaming access
- **MediaPlayer**: For local library and play count access
- **Graceful Fallback**: App works with any combination of permissions
- **Clear Messaging**: Users understand what data sources are available

## Current Functionality

### ✅ Working Features
- App launches and initializes Core Data
- Requests and handles music permissions
- Sets up playback monitoring for song completion detection
- Records song plays with full metadata (songID, albumID, artistID)
- Updates daily aggregates in real-time
- Displays setup progress and available features
- Handles different permission states gracefully
- Dual tracking system ready for immediate UI updates

### 🔄 Ready for Implementation
- Hot 100 chart calculation algorithms
- Chart UI with Billboard-style rankings
- Date range selection for flexible chart periods
- Chart movement indicators (up/down/new/re-entry)
- Artist/album/song detail views
- Export functionality
- iCloud sync preparation

## Data Flow Architecture

```
Song Completion → RecentPlay Record → Daily Aggregate Update → Chart Recalculation
                                   ↓
                            Notification Posted → UI Updates
```

### Entity Relationships
```
Song → belongs to → Album → belongs to → Artist
  ↓         ↓           ↓         ↓         ↓
RecentPlay → DailyAggregate → ChartSnapshot (for all 3 entity types)
```

## Technical Specifications

### Frameworks Used
- **Swift 5.9+** with iOS 18 deployment target
- **SwiftUI** for UI implementation
- **Core Data** for local storage with optimization
- **MusicKit** for Apple Music integration
- **MediaPlayer** for local library access
- **Combine** for reactive data flow

### Performance Optimizations
- Progressive aggregation prevents query slowdown
- Intelligent query strategy based on date ranges
- Core Data optimizations for large datasets
- Timer-based monitoring with minimal battery impact

## Known Limitations & TODOs

### Current Limitations
- No UI for viewing charts yet (data collection working)
- Chart calculation algorithms not implemented
- No date range selection interface
- No export functionality
- No cross-device sync

### Compilation Status
- ✅ All files compile successfully
- ✅ All import statements correct
- ✅ Core Data model properly configured
- ✅ Permission flows working
- ✅ Error handling implemented

## Next Stage Requirements

The foundation is solid and ready for:

1. **Chart Calculation Engine**
   - Implement Hot 100 algorithms for songs, albums, artists
   - Calculate movements and trends
   - Support flexible date ranges

2. **Chart UI Implementation**
   - Billboard-style ranked lists
   - Movement indicators and animations
   - Artwork and metadata display

3. **Date Range Selection**
   - Calendar picker interface
   - Preset ranges (week, month, year, all time)
   - Chart comparison between periods

4. **Advanced Features**
   - Detailed analytics
   - Export capabilities
   - Settings and preferences

## Key Success Metrics

This stage successfully established:
- ✅ **Unlimited data retention** - No arbitrary limits on history
- ✅ **Real-time tracking** - Immediate updates after each play
- ✅ **Three-entity support** - Songs, albums, and artists all tracked
- ✅ **Smart performance** - Scales to years of data
- ✅ **Robust permissions** - Handles all authorization states
- ✅ **Professional architecture** - Ready for production scaling

The app now has a bulletproof foundation for building the chart features and user interface in subsequent stages.