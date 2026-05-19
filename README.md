# YouTube Downloader Utils

Three small YouTube downloaders built for people with slow or unstable internet who need to save videos locally and watch later.

This repository contains:

- `youtube_downloader/`: a simple shell script downloader for fast one-off downloads
- `youtube_tui/`: a terminal UI downloader built with Textual
- `youtube_web_ui/`: a browser-based downloader built with Flask

All three tools use `yt-dlp` under the hood. For high-quality video+audio merging, `ffmpeg` is also required.

## Use Case

These tools are aimed at:

- students downloading lectures for offline study
- users on slow Wi‑Fi or mobile hotspots
- people who prefer downloading once and watching later without buffering

## Repository Layout

```text
youtube_downloader/
  download_lecture.sh

youtube_tui/
  app.py
  downloader.py
  requirements.txt
  run.sh
  style.tcss

youtube_web_ui/
  app.py
  requirements.txt
  start.sh
  static/
  templates/
```

## Requirements

Minimum system requirements:

- `python3` 3.10+
- `ffmpeg`
- internet access

Project dependencies:

- `yt-dlp`
- `Flask` for the web UI
- `textual` for the TUI

## Install `ffmpeg`

### macOS

```bash
brew install ffmpeg
```

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y ffmpeg python3-venv
```

## 1. Shell Downloader

Location: `youtube_downloader/download_lecture.sh`

This is the simplest option. It downloads the best available MP4 video and best audio, then merges them into a single MP4 file.

### Run

```bash
cd youtube_downloader
chmod +x download_lecture.sh
./download_lecture.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Notes

- This script currently assumes `Homebrew` is available when it needs to install missing tools.
- Output is saved in the current folder where the script is run.

## 2. Terminal UI Downloader

Location: `youtube_tui/`

This version provides:

- URL input
- video metadata lookup
- video or audio-only mode
- progress updates inside the terminal

### Run

```bash
cd youtube_tui
chmod +x run.sh
./run.sh
```

The launcher creates a virtual environment automatically if needed, installs dependencies, and starts the app.

### Manual run

```bash
cd youtube_tui
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

### Output

Downloaded files are saved to:

```text
youtube_tui/downloads/
```

## 3. Web UI Downloader

Location: `youtube_web_ui/`

This version provides:

- browser interface
- metadata lookup
- selectable video/audio formats
- progress polling
- download cancellation
- save-to-device flow after processing

### Run

```bash
cd youtube_web_ui
chmod +x start.sh
./start.sh
```

Then open:

```text
http://localhost:5001
```

The launcher creates a virtual environment automatically if needed, installs dependencies, and starts the Flask app.

### Manual run

```bash
cd youtube_web_ui
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

### Output

Downloaded files are stored in:

```text
youtube_web_ui/downloads/
```

## Recommended Setup

If you only want one tool:

- use the shell script for the quickest path
- use the TUI if you prefer the terminal
- use the web UI if you want a friendlier interface

If you are setting up the whole repo after cloning:

```bash
git clone https://github.com/geniesabbir/youtube-downloader-utils.git
cd youtube-downloader-utils
```

Then run whichever app you want from its own folder.

## Important Notes

- Downloading copyrighted content may violate platform rules or local law. Use these tools only for content you have the right to download.
- YouTube may change its delivery methods over time, so `yt-dlp` should be kept updated if downloads stop working.
- For best merged video quality, make sure `ffmpeg` is installed and available on your `PATH`.

## Troubleshooting

### `yt-dlp` download errors

Update dependencies inside the relevant app environment:

```bash
pip install --upgrade yt-dlp
```

### Merge fails or only one stream downloads

Install `ffmpeg` and verify:

```bash
ffmpeg -version
```

### `python3: command not found`

Install Python 3 and ensure it is available on your shell `PATH`.

## Author

Created by `geniesabbir`.
