# YT Utils Product Plan

Last updated: 2026-05-25
Owner: product + engineering
Working name: `YT Utils`

## Product Direction

`YT Utils` is not just a downloader.

The core value is still fast, reliable YouTube media capture, but that alone is too easy to copy. The app should win on:

- Better batch workflows than YouTube
- Better offline ownership than YouTube
- Better library organization than YouTube
- Faster access to saved media than YouTube
- Less friction for playlist-heavy and repeat-download users

## Current State

### Already implemented

- [x] Single video URL intake
- [x] Multiple URL paste intake
- [x] Audio-only toggle
- [x] Analyze before download flow
- [x] Completed file persistence across app reload
- [x] Save downloads to public Downloads when available
- [x] Queue + Library + Settings app structure
- [x] Local playback for audio and video
- [x] Search inside library
- [x] Branded app shell
- [x] Splash screen
- [x] First-time onboarding flow

### Implemented but needs refinement

- [ ] Batch UX for large pasted URL sets
- [ ] Queue management UX
- [ ] Better settings for download behavior
- [ ] More professional library structure

### Not implemented yet

- [ ] Playlist download flow
- [ ] Concurrent download control
- [ ] Separate video and audio library tabs
- [ ] Standardized media player UX
- [ ] Real native app icon assets
- [ ] Download quality controls
- [ ] Queue reorder / pause / resume all
- [ ] Storage usage manager
- [ ] Duplicate detection

## Research Summary

The opportunity is not “download YouTube”.
The opportunity is “make offline YouTube content usable”.

### What users clearly want

1. Better queue control
   Users complain about confusing queue behavior and poor multi-item queueing. For our app this translates to:
   `batch start`, `ordered queueing`, `pause/resume`, `reorder`, `clear completed`.

2. Better playlist handling
   Users repeatedly complain about weak playlist management and poor large-list workflows. For us this means:
   `playlist ingestion`, `playlist-level download`, `playlist progress`, `playlist retry`, `playlist foldering`.

3. Better offline reliability
   Official YouTube offline playback is region-limited and requires periodic reconnects. User complaints also repeatedly mention buggy offline downloads and unreliable downloaded playlists. Our advantage should be:
   `true local files`, `persistent library`, `resume-safe downloads`, `storage visibility`, `offline-first playback`.

4. Better organization
   Users ask for search in playlist, sorting, folders, favorites, easier removal, and library management. For us this means:
   `audio/video split`, `sort/filter`, `collections`, `favorite`, `tags`, `channel-based grouping`.

5. Better control over saved media
   Users want media to feel owned, not trapped inside a streaming app. Our advantage should be:
   `public storage`, `open with other apps`, `share file`, `rename`, `move`, `export metadata`, `standard players`.

## Product Roadmap

## Phase 1: Core Downloader Refinement

Goal: make core downloading solid enough that users trust it.

### 1. Batch start flow

Problem:
Right now large pasted URL sets are analyzed and added immediately. That works, but it becomes noisy and less controllable.

Plan:

- [ ] Add a review state for pasted URLs
- [ ] Show detected valid URLs count before queue insertion
- [ ] Add `Start Batch` button
- [ ] Add `Cancel Batch` button
- [ ] Allow removing individual links from the staged batch before insertion

Success criteria:

- Users can paste 20-100 URLs without instantly flooding the queue
- Batch jobs feel deliberate instead of accidental

### 2. Concurrent downloads setting

Problem:
Downloading too many files at once can split bandwidth and worsen completion reliability.

Plan:

- [ ] Add `Concurrent downloads` setting in Settings
- [ ] Default value: `3`
- [ ] Allowed range: `1-5`
- [ ] Update queue processor to run up to configured concurrency
- [ ] Show active vs waiting state in queue

Success criteria:

- User controls speed vs concurrency tradeoff
- Default behavior is stable for average mobile users

### 3. Playlist download

Problem:
Playlist download is one of the most useful real-world workflows and currently missing.

Plan:

- [ ] Detect playlist URLs separately from single video URLs
- [ ] Resolve playlist entries before queueing
- [ ] Show playlist summary before starting
- [ ] Allow `Download all`, `Download selected`, `Audio only`, `Video only`
- [ ] Add playlist progress row
- [ ] Handle duplicates gracefully

Success criteria:

- User can paste one playlist link and control the whole batch from one place

### 4. Better queue controls

Plan:

- [ ] Pause individual item
- [ ] Resume individual item
- [ ] Pause all
- [ ] Resume all
- [ ] Reorder queue
- [ ] Retry failed all
- [ ] Clear completed

## Phase 2: Library Upgrade

Goal: make saved media feel like a real offline archive, not a raw file dump.

### 5. Split Audio and Video libraries

Problem:
Audio and video use cases are different.

Plan:

- [ ] Replace single Library view with:
  - `Videos`
  - `Audio`
  - optional future `Playlists` or `Collections`
- [ ] Keep shared search
- [ ] Add per-tab filters and sort

Success criteria:

- Users can reach podcasts/music-style saves separately from full videos

### 6. Standard playback experience

Problem:
Custom players are only worth it if they are clearly better. Otherwise they feel less trustworthy.

Plan:

- [ ] Use straightforward, standard controls for video playback
- [ ] Use straightforward, standard controls for audio playback
- [ ] Add seek, speed, skip, lock-screen continuity where possible
- [ ] Keep player UI familiar, not experimental

Success criteria:

- New users understand playback instantly

### 7. Organization and findability

Plan:

- [ ] Sort by recent, title, channel, duration, size
- [ ] Filter by audio/video
- [ ] Favorite / star items
- [ ] Tag editor improvement
- [ ] Channel grouping
- [ ] Collections or folders
- [ ] Duplicate warnings before download

## Phase 3: Features YouTube Does Poorly

Goal: build features users actually miss, not filler.

### 8. Reliable offline ownership

Plan:

- [ ] Show exact saved location
- [ ] Open containing folder
- [ ] File size and storage usage
- [ ] Bulk delete
- [ ] Detect missing files and repair metadata
- [ ] Re-scan local storage manually

### 9. Better metadata utility

Plan:

- [ ] Keep chapter extraction
- [ ] Save chapter markers with media item
- [ ] Add description snippet / notes
- [ ] Add transcript import when feasible
- [ ] Allow rename before or after download

### 10. Smart “utility” features

These are the best candidates that go beyond basic downloading:

- [ ] Channel watchlist to monitor new uploads
- [ ] Auto-download new videos from chosen channels/playlists
- [ ] Convert long videos to audio with clean naming
- [ ] Batch file rename rules
- [ ] “Save only selected chapters” concept research
- [ ] Share/export local file plus metadata

## Feature Prioritization

### P0

- [ ] Batch start flow
- [ ] Concurrent downloads setting
- [ ] Playlist download
- [ ] Audio/Video split library
- [ ] Standard player cleanup
- [ ] Rename app to `YT Utils` across UI and platform metadata

### P1

- [ ] Queue reorder / pause / resume all
- [ ] Sorting and filters
- [ ] Duplicate detection
- [ ] Storage usage manager
- [ ] Native app icon assets

### P2

- [ ] Collections / folders
- [ ] Auto-download from playlists/channels
- [ ] Transcript / notes / metadata enrichment

## Engineering Tasks

## Branding

- [x] Change visible app name to `YT Utils`
- [x] Update Android app label
- [x] Update iOS display name
- [x] Replace native splash assets
- [ ] Replace launcher icons

## Downloader

- [ ] Introduce staged batch model
- [ ] Add playlist parsing pipeline
- [ ] Add concurrency setting persistence
- [ ] Refactor queue processor for multi-active jobs
- [ ] Add duplicate check by video id / canonical URL

## Library

- [ ] Split library UI into audio/video tabs
- [ ] Add sorting + filtering model
- [ ] Add file stats
- [ ] Add manual re-scan action

## Playback

- [ ] Simplify player UI
- [ ] Add playback speed presets
- [ ] Add skip forward/back controls

## Decisions

### Accepted

- [x] Public Downloads storage is better than hidden app-only storage for this product
- [x] Vault/private file concept is removed
- [x] Onboarding + splash are worth keeping
- [x] Downloader remains the core feature

### Rejected

- [x] Vault / biometric storage
- [x] Complex novelty player UX before stable standard playback

## Progress Tracker

Use this section as the single execution tracker.

### Done

- [x] Core single URL flow
- [x] Core multi-URL paste flow
- [x] Public download storage
- [x] Queue persistence across reload
- [x] Library persistence across reload
- [x] Brand shell
- [x] First-time onboarding
- [x] Vault removal

### In Progress

- [ ] Professional app polish

### Next Up

- [ ] Batch start flow
- [ ] Concurrent download setting
- [ ] Playlist download
- [ ] Audio/video split library
- [ ] Standard player upgrade

## Suggested Build Order

1. Rename app to `YT Utils`
2. Add concurrent download setting
3. Build staged batch start flow
4. Add playlist parsing + playlist download
5. Split audio/video library
6. Simplify and standardize playback
7. Add sorting, filtering, duplicate detection
8. Add native icon assets

## Notes

- Keep this product focused on utility and reliability, not gimmicks.
- If a feature does not reduce friction for repeat download users, it should probably not ship.
- Playlist-heavy users and offline-heavy users are the highest-value audience.

## Sources

- YouTube Help: offline downloads are region-limited, require reconnect rules, and are managed inside the mobile Library/Downloads flow.
  https://support.google.com/youtube/answer/6141269?hl=en-GB
- Community complaints around missing playlist search, queue behavior, and playlist organization in YouTube Music:
  https://www.reddit.com/r/YoutubeMusic/comments/1m8710j/just_started_using_youtube_music_and/
- Community complaints around playlist reorganization, folders, queue loss, and library organization:
  https://www.reddit.com/r/YoutubeMusic/comments/1r1nyu5/every_feature_that_is_missing_on_youtube_music/
- Community complaints around buggy offline/downloaded playlist behavior:
  https://www.reddit.com/r/YoutubeMusic/comments/1kbifoi
  https://www.reddit.com/r/YoutubeMusic/comments/1mhkxk7/large_playlist_will_not_finish_downloading/
