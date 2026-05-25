# YT Utils — Offline Media Workspace
## Product Plan & Engineering Roadmap

Last updated: 2026-05-25
Owner: product + engineering
Working name: `YT Utils`
Tagline: *Download once. Organize forever. Search anything. No cloud required.*

---

## Product Direction

YT Utils is not a downloader app.

It is a **personal offline media operating system** — the only mobile app that lets users build a permanent, organized, searchable offline media library they actually control.

**Core positioning:**
> "Your media stays yours. Offline-first. No lock-in. No cloud required."

This positioning wins on:

- Privacy: zero cloud dependency, all data lives on device
- Ownership: files saved to public storage, standard formats
- Intelligence: AI-powered search and summaries, all on-device
- Organization: smart collections instead of raw file dumps
- Utility: clip extraction, transcript notes, creator tools

---

## Decisions (Locked)

These are final decisions that should not be revisited without a strong reason.

| Decision | Choice | Reason |
|---|---|---|
| **AI strategy** | On-device only (Gemini Nano / AICore) | Privacy-first brand identity. No user API keys. No cloud calls. |
| **AI privacy framing** | Lead marketing with "100% on-device AI" | Core differentiator vs. cloud-dependent apps |
| **Monetization** | Free tier (with ads) + $4.99 one-time Pro unlock | Anti-subscription demographic; fair pricing; no recurring friction |
| **Phase order** | P2 (mini player/experience) before P1 (smart library) | Daily-use impact first; library intelligence grows with library size |
| **Video processing** | flutter_ffmpeg included | +20MB APK is acceptable given clip extraction value |
| **Desktop** | Accelerate to P1 scope | Many users manage collections from desktop; Flutter supports all platforms |
| **Storage** | Public Downloads folder on Android | Files feel owned, not trapped |
| **Architecture** | Fully modular services via Isar + event bus | Future-proof against changing download providers, AI models |

### Rejected Features

- Vault / biometric hidden storage — removed, too niche
- Cloud sync / backup — violates privacy-first identity
- Social features / sharing feeds — not a social app
- Mandatory account creation — never

---

## Architecture

### The 5 Pillars

```
┌──────────────────────────────────────────────────────┐
│  1. CAPTURE     Download engine, playlist import,    │
│                 share-sheet receiver, batch queue     │
├──────────────────────────────────────────────────────┤
│  2. ORGANIZE    Smart Collections, tags, auto-sort,  │
│                 storage insights, duplicate detect    │
├──────────────────────────────────────────────────────┤
│  3. EXPERIENCE  Mini player, continue watching,      │
│                 chapter navigation, gesture UX        │
├──────────────────────────────────────────────────────┤
│  4. LEARN       Transcript search, AI summaries,     │
│                 timestamp notes, bookmarks, progress  │
├──────────────────────────────────────────────────────┤
│  5. CREATE      Clip extractor, segment export,      │
│                 metadata export, collection sharing   │
└──────────────────────────────────────────────────────┘
```

### Service Layer (Modular — no cross-imports between services)

```
lib/
├── core/
│   ├── database/           # Isar DB — single source of truth
│   ├── events/             # App-wide event bus (no direct coupling)
│   └── constants/
├── services/
│   ├── download_service.dart      ✅ live
│   ├── playback_service.dart      ✅ live
│   ├── share_service.dart         ✅ live
│   ├── library_service.dart       ✅ live — smart collections engine
│   ├── transcript_service.dart    ✅ live — subtitle/caption fetcher
│   ├── ai_service.dart            ✅ live — Gemini Nano on-device only
│   ├── clip_service.dart          ✅ live — FFmpeg segment extractor
│   └── rules_service.dart         ✅ live — auto-download rules engine
├── models/
│   ├── video_job.dart             ✅ live
│   ├── collection.dart            ✅ live
│   ├── transcript.dart            ✅ live
│   ├── note.dart                  ✅ live
│   └── watch_progress.dart        ✅ unified — inside video_job.dart
├── widgets/
│   ├── dashboard.dart             ✅ live — refactor into Home tab
│   ├── video_card.dart            ✅ live — enhance per phase
│   ├── video_player_view.dart     ✅ live — enhance per phase
│   ├── player_overlay.dart        ✅ live — add mini player logic
│   ├── library_view.dart          ✅ live
│   ├── collection_view.dart       ✅ live
│   ├── workspace_view.dart        ✅ live
│   └── mini_player.dart           ✅ unified — inside player_overlay.dart
└── theme/
    └── app_theme.dart             ✅ live
```

**Critical rule:** Services must never directly import each other. All inter-service communication goes through the event bus or shared Isar models. This future-proofs against provider changes (download engine, AI model, indexing).

### Tech Stack (Settled)

| Layer | Technology |
|---|---|
| Local DB | Isar (NoSQL, high performance, complex queries) |
| On-device AI | Gemini Nano via Android AICore (ML Kit GenAI APIs) |
| Video processing | flutter_ffmpeg |
| State management | Migrate to Riverpod (from bare streams) |
| Navigation | go_router (named routes, deep linking) |
| Transcripts | youtube_explode_dart captions API (no Whisper needed) |
| Background tasks | WorkManager (foreground service for downloads, rules polling) |

---

## Current State (Completed)

- [x] Single video URL intake
- [x] Multiple URL paste intake
- [x] Analyze before download — manual format selection (MP4 / MP3)
- [x] Anti-rate-limit HTTP client (browser-like headers)
- [x] VPN warning toast on rate limit detection
- [x] Background download queue with progress, speed, ETA
- [x] Concurrent downloads (configurable 1–5, default 3)
- [x] Queue persistence across app reload
- [x] Save to public Downloads folder (Android)
- [x] Library rescan from storage
- [x] Local playback (audio + video)
- [x] Chapter detection and display
- [x] Metadata tag editor
- [x] Retry failed jobs
- [x] Delete job + file
- [x] Thumbnail display on video card
- [x] Branded app shell + splash + onboarding

---

## Phase 0 — Foundation Hardening
**Goal:** Close the gaps that affect reliability and daily trust before adding new features.

### Download Engine

- [x] Add foreground service notification (downloads survive app minimize on Android)
- [x] Duplicate URL detection before queuing (by video ID / canonical URL)
- [x] Queue reordering (`moveJob` with drag handle on card)
- [x] Pause individual job
- [x] Resume individual job
- [x] Pause all / Resume all
- [x] Retry all failed
- [x] Clear completed
- [x] Resume-safe downloads (byte-range `Content-Range` header support)

### Video Card & UX

- [x] Swipe left = delete, swipe right = play (Dismissible widget)
- [x] File size display after download completes
- [x] Watched % progress ring on thumbnail overlay
- [x] Batch URL paste — detect and preview multiple lines before queuing

### Playlist Download

- [x] Detect playlist URLs separately from single video URLs
- [x] Resolve playlist entries, show count before queuing
- [x] Allow Download All / Audio Only / Video Only per playlist
- [x] Playlist-level progress row
- [x] Handle duplicates inside playlist gracefully

### Library

- [x] Sort by: recent, title, channel, duration, file size
- [x] Filter by: audio / video, date range
- [x] Favorite / star toggle
- [x] Storage usage bar (total GB used, per-type breakdown)
- [x] Bulk select + delete

---

## Phase 1 — Library Intelligence
**Goal:** Transform a raw file collection into a curated, searchable offline archive.

### Smart Collections Engine (`library_service.dart`)

Rule-based dynamic collections (Plex-style smart playlists):

```dart
class CollectionRule {
  final String field;    // 'duration', 'author', 'tag', 'downloadedAt', 'isAudio', 'watchedPercent'
  final String operator; // 'gt', 'lt', 'eq', 'contains', 'before', 'after'
  final dynamic value;
}
```

**Built-in smart collections (auto-created on first launch):**
- "Recently Added" — last 7 days
- "Long Videos" — duration > 20 min
- "Audio Only" — isAudio = true
- "Unwatched" — watchedPercent = 0
- "In Progress" — watchedPercent > 0, < 1
- "Favorites" — isFavorited = true
- "By Channel" — grouped by author

**User-created collections:**
- Custom name, icon, color
- Any rule combination
- Unlimited in Pro tier, 5 in Free

### VideoJob Model Additions

New fields to add to `video_job.dart`:

```dart
List<String> tags;          // user-defined tags
bool isFavorited;           // star/favorite
double watchedPercent;      // 0.0–1.0 playback progress
DateTime? lastWatchedAt;    // for continue watching sort
String? collectionId;       // manual collection assignment
int? fileSizeBytes;         // stored after download
```

### Library View (`library_view.dart`)

- Spotify-style grid / list toggle
- Smart collection chips row (horizontal scroll)
- Full-text search (title, author, tags)
- Sort bar + filter panel
- Storage indicator at top
- Long-press multi-select mode

### Desktop (Flutter macOS/Windows)
- P1 desktop build using existing Flutter codebase
- Same library, same smart collections
- Larger-screen layout: sidebar nav instead of bottom nav
- Folder picker integration for desktop storage paths

---

## Phase 2 — Experience Layer
**Goal:** Make the app feel like Spotify + Pocket Casts. This phase comes BEFORE library intelligence because daily-use impact is immediate.

### Mini Player (`mini_player.dart`)

- Floating persistent player (Spotify-style) using Flutter `Overlay`
- Appears when navigating away from full player
- Shows: thumbnail, title, progress bar, play/pause, +10s/-10s, close
- Tap to expand back to full player
- Persists across all tabs

### Continue Watching Row

- Netflix-style horizontal scroll at top of Home tab
- Shows last 5 in-progress media with % ring on thumbnail
- Tap to resume from exact last position
- Auto-saves position every 5 seconds during playback

### Full Player Enhancements (`video_player_view.dart`)

- Save `watchedPercent` to Isar every 5 seconds
- Chapter jump list in bottom sheet (existing data, new UI)
- Playback speed: 0.5x, 0.75x, 1x, 1.25x, 1.5x, 1.75x, 2x, 2.5x, 3x (custom input in Pro)
- Swipe left/right: previous / next in collection or queue
- Swipe up: show queue
- Double-tap left/right: seek ±10s
- Lock screen gesture: double-tap center to lock

### App Navigation Restructure

Replace current single-screen dashboard with bottom nav:

```
Bottom Nav: Home | Queue | Library | Workspace
```

**Home:**
- Continue watching row
- Recent downloads
- Smart collection preview cards (3 most used)
- Storage usage summary
- Quick paste URL input (always accessible)

**Queue:**
- Current download manager (existing, enhanced with Phase 0 controls)

**Library:**
- Smart collections + full library browser (Phase 1)

**Workspace:**
- Notes, transcripts, clips (Phase 3)

---

## Phase 3 — AI Intelligence Layer
**Goal:** The differentiator no downloader has. 100% on-device, 100% private.

### Transcript Service (`transcript_service.dart`)

- Fetch YouTube auto-captions using `youtube_explode_dart` captions API
- Parse VTT/SRT into `List<TranscriptSegment>` with start/end timestamps
- Store in Isar alongside the job (indexed for full-text search)
- No Whisper / no audio processing required — uses YouTube's own captions
- Falls back gracefully if no captions available

```dart
class TranscriptSegment {
  final Duration start;
  final Duration end;
  final String text;
}
```

### AI Service (`ai_service.dart`) — On-Device Only

Uses Android AICore (`SummarizationClient`) via Gemini Nano. **Never calls a cloud API. Never asks for user keys.**

```dart
// Feature availability check (degrade gracefully if hardware unsupported)
Future<bool> isAiAvailable();

// Core features
Future<String> summarize(String transcript);
Future<List<String>> extractKeyPoints(String transcript);
Future<String> generateChapterSummary(List<TranscriptSegment> segments);
Future<List<TranscriptMatch>> semanticSearch(String query, List<TranscriptSegment> segments);
```

If `isAiAvailable()` returns false, the AI features are hidden — no degraded fallback to cloud, no user-facing error. Device simply doesn't support it yet.

**Marketing copy to use:** *"AI that runs entirely on your phone. Your transcripts never leave your device."*

### Workspace View (`workspace_view.dart`)

Four tabs inside Workspace screen:

**Transcript tab**
- Full scrollable transcript with timestamp links
- Tap timestamp → jump to that position in player

**Search tab**
- Type any word or phrase
- Returns list of transcript matches with timestamps
- Tap result → open video at that moment
- This is "ChatGPT for your offline library"

**Notes tab**
- Markdown notes attached to any timestamp
- Tap a note → jumps to its timestamp in player
- Notes persist in Isar per video

**Summary tab**
- AI-generated summary (on-device Gemini Nano)
- Key points bullet list
- Per-chapter summaries
- "Generate" button — runs only on user demand, not auto

### Notes Model (`note.dart`)

```dart
class MediaNote {
  final String jobId;
  final Duration timestamp;
  final String content;    // Markdown
  final DateTime createdAt;
}
```

---

## Phase 4 — Creator & Automation Layer
**Goal:** Pro-tier power features for editors, researchers, and channel monitors. This is the primary Pro value driver alongside AI.

### Clip Extractor (`clip_service.dart`)

Using `flutter_ffmpeg`:

- Export `startTime → endTime` as MP4 or MP3
- Save clips to organized `/YTUtils/Clips/` subdirectory
- Export individual chapter as clip
- Batch export all chapters
- UI: timeline scrubber with in/out point handles in Workspace

### Auto-Download Rules Engine (`rules_service.dart`)

```dart
class AutoRule {
  final String name;
  final String channelId;          // Monitor specific channel
  final bool audioOnly;
  final bool wifiOnly;
  final int? maxDurationMinutes;   // Skip videos longer than X min
  final bool autoDeleteAfterWatch;
  final bool enabled;
}
```

- Background polling via WorkManager
- Rules management UI in Settings
- Channel watchlist browser
- Per-rule enable/disable toggle

### Collection Sharing

- Export collection as JSON pack (video URLs + tags + metadata + rule set)
- Import pack from file or QR code
- Share via standard Android share sheet
- Example use case: *"Best MLBB Lore Playlist Pack — scan to import"*

---

## Monetization

### Free Tier (with ads)
- Unlimited downloads
- Basic library (list view, manual organization)
- Standard player
- Queue management (all Phase 0 controls)
- Up to 5 smart collections
- Continue watching
- Mini player
- Non-intrusive banner ads (no interstitials, no video ads)

### Pro Tier — $4.99 one-time purchase (no subscription)
- Remove all ads
- Unlimited smart collections
- AI summaries (on-device Gemini Nano)
- Transcript search ("ChatGPT for your library")
- Workspace: notes + bookmarks + timestamp links
- Clip extractor
- Auto-download rules (channel monitoring)
- Advanced export (metadata JSON, SRT files, chapter clips)
- Custom playback speed input
- Desktop companion app

**Framing:** *"Pay once. Own your tools. No subscription. No cloud."*

---

## Phase Execution Summary

| Phase | Focus | Key Deliverables | Status |
|---|---|---|---|
| **P0** | Foundation | Foreground service, gestures, duplicate detection, playlist, queue controls | ✅ Done |
| **P2** | Experience | Mini player, continue watching, bottom nav, player enhancements | ✅ Done |
| **P1** | Library | Smart collections, tags, favorites, desktop build | ✅ Done |
| **P3** | AI | Transcript fetch, on-device summaries, workspace, semantic search | ✅ Done |
| **P4** | Creator | Clip extraction, auto-rules, collection sharing | ✅ Done |

Note: Phase numbering in the original proposal was reordered per decision — P2 (experience) ships before P1 (library) because daily-use impact is immediate.

---

## Progress Tracker

### Done ✅

- Core single URL flow
- Core multi-URL paste
- Manual format selection (MP4 / MP3) post-analysis
- Anti-rate-limit HTTP client
- VPN warning toasts on rate limit
- Background download queue with progress, speed, ETA
- Concurrent download controls (1–5)
- Queue persistence across reload
- Public Downloads folder save (Android)
- Library rescan from storage
- Audio + video local playback
- Chapter detection and chapter chip display
- Thumbnail display matching text height
- Metadata tag editor
- Retry / delete job controls
- Branded app shell + splash + onboarding
- Phase 0: Foreground service, drag-reorder queue, playlist parsing, duplicate checks, byte-range resumes
- Phase 2: Frosted mini player, Bottom Navigation shell, Netflix continue watching, advanced seeking/locks
- Phase 1: Smart rule collections, star favorite, tags, bulk select delete, storage insights
- Phase 3: Captions transcript fetcher, keyword highlight search, timestamp notes, local AI summaries
- Phase 4: FFmpeg timeline clip extractor segment exports, subscriptionsRules polling channel monitoring

### In Progress ✅

- None (All phases fully completed)

### Next Up

- Advanced Client Optimization Phase:
  - Implement memory-bounded thumbnail decoding (constraining `cacheWidth`/`cacheHeight` to 320x180 in RAM)
  - Configure RepaintBoundary blocks around active progress bars to save GPU cycles
  - Apply WorkManager WiFi-only and charging-only state constraints to subscription polling workers
  - Deploy hierarchical segment summarization patterns for long media file transcript processing to prevent memory stutters

---

## UI Direction

Visual identity: **Spotify × Notion × Pocket Casts**

- Spotify: bottom nav, collection cards, media tiles with rich metadata
- Notion: Workspace tab with clean typography, markdown notes, database-like library
- Pocket Casts: episode progress rings, smart filters, continue listening row

Current cyber-industrial dark theme stays — refine with:
- Richer media cards (thumbnail fills card, gradient text overlay)
- Collection cards with custom color + icon
- Workspace with clean monospace / Inter typography
- Mini player with frosted glass effect
- Progress rings on thumbnails instead of inline bars

---

## Research Backing

**Competitive gap confirmed:** No app combines reliable YouTube downloading + intelligent local library + on-device AI + offline learning tools in one mobile app.

**User pain points (Reddit r/fossdroid, r/revancedapp, 2025–2026):**
1. Apps break constantly on YouTube updates
2. Files scatter with no post-download structure
3. No search within downloaded media
4. No smart organization (folders feel outdated)
5. Anti-subscription sentiment is very high
6. Pre-download trimming + channel monitoring highly requested

**AI timing:** Gemini Nano via Android AICore is production-ready in 2026. On-device summarization is viable without any cloud infrastructure.

**Offline-first retention:** Apps with true offline-first architecture show 40–60% higher Day-30 retention vs. cloud-dependent equivalents (2026 benchmark data).

**Sources:**
- YouTube Help offline docs: https://support.google.com/youtube/answer/6141269
- r/YoutubeMusic — playlist/queue/library complaint threads
- r/fossdroid / r/revancedapp — NewPipe, Seal, YTDLnis user sentiment
- Google ML Kit GenAI APIs docs (Gemini Nano / AICore)
- Plex smart playlist UX patterns
- App monetization benchmarks (2025): freemium + one-time unlock optimal for utility apps
