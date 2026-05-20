# VOID-ARCHIVE TUI

Terminal UI for discovering and downloading YouTube videos with `yt-dlp` and `Textual`.

This version is built around isolated video jobs:

- One input can contain one or many URLs.
- Discovery runs per source URL.
- Each discovered video gets its own controls.
- Discovery retry and download retry are handled per video card.
- Download progress is isolated per video instead of sharing one global progress bar.

## Features

- Batch URL input using spaces or commas as separators
- Discovery of single videos and multi-entry sources
- Per-video download as MP4
- Per-video audio download as MP3
- Retry discovery for failed jobs
- Retry download for failed jobs
- Individual progress bars and statuses for each video

## Requirements

- Python 3.10+
- `ffmpeg` available on `PATH` for merge and audio extraction

## Install

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Run

Use the helper script:

```bash
./run.sh
```

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

Downloaded files are saved to the `downloads/` directory.

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
