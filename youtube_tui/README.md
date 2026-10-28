# VOID-ARCHIVE TUI

Universal Terminal UI for discovering and downloading videos and audio from YouTube, Facebook, Dailymotion, TikTok, Vimeo, X/Twitter, Instagram, Reddit, and 1,800+ platforms with `yt-dlp` and `Textual`.

This version is built around isolated video jobs:

- One input can contain one or many URLs across any supported platform.
- Discovery runs per source URL.
- Each discovered video gets its own controls and platform badge.
- Optional per-video start and end timestamp trimming.
- Discovery retry and download retry are handled per video card.
- Download progress is isolated per video instead of sharing one global progress bar.

## Features

- Batch URL input across YouTube, Facebook, Dailymotion, TikTok, Vimeo, X/Twitter, Instagram, Twitch, and all `yt-dlp` supported extractors
- Automatic platform detection badge for every queued video
- Discovery of single videos and multi-entry sources/playlists
- Per-video timestamp range trimming (e.g., `00:30` to `02:15` or seconds)
- Per-video download as MP4 (defaults to best resolution)
- Per-video audio download as MP3
- Automatic fallback to public video access if cached cookies are invalid/expired
- Multi-platform cookie session management (YouTube, Facebook, Instagram, Twitter/X, TikTok, Reddit, etc.)
- Automatic YouTube signature decryption support using `yt-dlp-ejs` and local JS runtimes
- Retry discovery for failed jobs
- Retry download for failed jobs
- Individual progress bars and statuses for each video

## Requirements

- Python 3.10+
- `ffmpeg` available on `PATH` for merge and audio extraction
- A JavaScript runtime (`deno`, `node`, or `bun`) available on `PATH` for solving signature decryption challenges when authenticated cookies are loaded

## One-Click Terminal Install (Recommended)

To install Void-Archive into any terminal without doing any extra manual setup:

```bash
curl -fsSL https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.sh | bash
```

Or from inside this repository:

```bash
./install.sh
```

### What this does automatically:
- Installs the isolated runtime and all dependencies to `~/.local/share/void-archive`
- Automatically checks/installs `ffmpeg`
- Exposes the command **`void-archive`** (alias **`youtube-tui`**) in your terminal `PATH`
- **Binds downloads directly to your device's native Downloads folder (`~/Downloads`)**
- Configures auto-update via `void-archive --update`

Once installed, simply open any terminal and run:

```bash
void-archive
```

---

## Manual Install & Local Development

If you prefer to run directly from the source directory:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
./run.sh
```

## Run

Use the helper script:

```bash
./run.sh
```

The helper script now bootstraps the runtime automatically:

- creates the virtual environment when missing
- installs the pinned versions from `requirements.txt`
- attempts to install `ffmpeg` through Homebrew when `ffmpeg` is missing
- reuses a valid cached signed-in cookie session when available
- scans supported browsers for a signed-in YouTube/Google cookie session only when no valid cached session exists

If you want to intentionally refresh dependencies, use:

```bash
./run.sh --update
```

That mode upgrades packaging tools and refreshes the pinned application dependencies.

If you already want to force a specific auth path, `YTDLP_COOKIES_FILE`, `YTDLP_BROWSER_SPEC`, and `YTDLP_COOKIES_FROM_BROWSER` still take precedence.

Or run directly:

```bash
source venv/bin/activate
python3 app.py
```

## Usage

1. Paste one or more YouTube URLs into `DISCOVER URLS`.
2. Separate URLs with spaces or commas.
3. Click `ANALYZE URLS`.
4. Wait for discovery jobs to complete.
5. For each discovered video card, choose:
   - `Download Video`
   - `Download Audio`
6. If discovery fails for a card, use `Retry Discover`.
7. If download fails for a card, use `Retry Download`.

Downloaded files are automatically saved to your device's native **`~/Downloads`** folder.

> **Tip**: You can customize the download location at any time by setting `export VOID_DOWNLOAD_DIR="/custom/path"`.

## YouTube Authentication

Some YouTube URLs now reject anonymous `yt-dlp` requests with:

`Sign in to confirm you're not a bot`

This app supports passing cookies through environment variables before launch.

Preferred: pass a full `yt-dlp` browser spec:

```bash
export YTDLP_BROWSER_SPEC=brave
./run.sh
```

Examples:

- `YTDLP_BROWSER_SPEC=brave`
- `YTDLP_BROWSER_SPEC=chrome:Profile 1`
- `YTDLP_BROWSER_SPEC=chromium:/full/profile/path`
- `YTDLP_BROWSER_SPEC=firefox:default`

Backward-compatible fallback:

```bash
export YTDLP_COOKIES_FROM_BROWSER=brave
./run.sh
```

Or use an exported cookies file:

```bash
export YTDLP_COOKIES_FILE=/absolute/path/to/cookies.txt
./run.sh
```

TUI export flow:

- Enter a browser spec in the `EXPORT COOKIES` field, such as `brave` or `chrome:Profile 1`
- Click `EXPORT COOKIES`
- The app will export cookies to `~/.cache/void-archive/youtube.cookies.txt`
- The current TUI session will immediately switch to that cookie file
- Future discovery and download actions will reuse that exported file first, which avoids repeated macOS Keychain prompts
- The TUI tracks cookie expiry from the exported file and will:
  - warn when the cookies are close to expiry
  - block discovery when the cookies are expired or missing
  - ask for re-export before continuing

This keeps the UX one-click inside the app for supported browsers, while still using a stable file-based auth path for downloads.

Arc-specific note:

- Arc is not a supported `--cookies-from-browser` name in `yt-dlp`.
- On macOS, Arc cookies may also fail decryption through Chromium-compatible extraction.
- For Arc, `YTDLP_COOKIES_FILE=/absolute/path/to/cookies.txt` is the reliable path.

Priority order:

1. `YTDLP_BROWSER_SPEC`
2. `YTDLP_COOKIES_FROM_BROWSER`
3. `YTDLP_COOKIES_FILE` can be combined with either and is the safest fallback

## Architecture

The TUI uses a job-oriented design instead of a single shared controller.

- `app.py`
  - Owns UI state and job lifecycle
  - Parses multi-URL input
  - Creates one `VideoJobState` per discovered item
  - Maps per-job actions to discovery and download tasks
- `downloader.py`
  - Wraps `yt-dlp`
  - Normalizes discovery results
  - Streams per-download progress events back to the UI
- `style.tcss`
  - Styles the batch discovery layout and per-video cards

## Failure Model

The app is intentionally designed so failures stay local to a video job.

- A failed discovery does not block other discovered videos.
- A failed download does not interrupt other downloads.
- Retry actions only re-run the failed job, not the whole batch.

This keeps the TUI predictable and closer to how production job systems are structured.

## Notes

- `yt-dlp` behavior depends on the source URL and upstream platform responses.
- Playlist or multi-entry discovery may create multiple video cards from one source URL.
- Audio extraction to MP3 depends on `ffmpeg` being installed correctly.

## Project Files

- [app.py](/Users/genie-sabbir/Documents/antigravity/game_dev/youtube_tui/app.py)
- [downloader.py](/Users/genie-sabbir/Documents/antigravity/game_dev/youtube_tui/downloader.py)
- [style.tcss](/Users/genie-sabbir/Documents/antigravity/game_dev/youtube_tui/style.tcss)
- [run.sh](/Users/genie-sabbir/Documents/antigravity/game_dev/youtube_tui/run.sh)
- [requirements.txt](/Users/genie-sabbir/Documents/antigravity/game_dev/youtube_tui/requirements.txt)
