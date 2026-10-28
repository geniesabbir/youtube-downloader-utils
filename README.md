# YouTube Downloader Utils

A collection of lightweight YouTube downloader utilities built for people with slow or unstable internet connections who want to save videos and lectures for offline viewing.

This repository includes three separate downloader experiences:

- a simple shell-based downloader
- a terminal UI built with Textual
- a web UI built with Flask

All tools use `yt-dlp` as the download engine, with `ffmpeg` used for merging high-quality video and audio streams when needed.

## Why This Repo Exists

Streaming is not always practical. In many cases, users deal with:

- weak Wi‑Fi
- limited mobile data
- unstable rural internet
- long commutes without connectivity

This project is intended to make offline-first video access easier, especially for educational content such as recorded lectures and tutorials.

## Features

- three downloader interfaces for different user preferences
- high-quality video downloads using `yt-dlp`
- audio-only download support
- terminal-based progress feedback
- browser-based format selection and progress tracking
- local-first workflow with downloaded files saved on device

## Included Apps

### 1. Shell Downloader

Path: `youtube_downloader/download_lecture.sh`

Best for users who want a minimal command-line workflow.

Capabilities:

- accepts a single YouTube URL
- downloads the best MP4 video and best audio available
- merges streams into one MP4 file

### 2. Terminal UI Downloader (Void-Archive)

Path: `youtube_tui/`

Best for users who prefer working inside the terminal with a sleek interactive interface.

**One-Click Install in any terminal:**
```bash
curl -fsSL https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.sh | bash
```
Once installed, run `void-archive` from any folder.

Capabilities:

- paste a link and inspect metadata
- download video (defaults to best resolution) or audio-only mode
- automatic YouTube signature (`n` challenge decryption) decryption support using local JS runtimes
- watch progress updates live
- save output directly into your device's native `~/Downloads` folder

### 3. Web UI Downloader

Path: `youtube_web_ui/`

Best for users who want a friendlier browser-based experience.

Capabilities:

- analyze a YouTube URL in the browser
- inspect available formats
- choose video+audio, video-only, or audio-only
- track progress and cancel downloads
- save the generated file locally after processing

## Project Structure

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

System requirements:

- `python3` 3.10 or newer
- `ffmpeg` available on `PATH` for merging and extracting audio
- A JavaScript runtime (`deno`, `node`, or `bun`) available on `PATH` for YouTube signature decryption challenge solving
- internet access

Python packages used in this repo:

- `yt-dlp` (with `yt-dlp-ejs` and standard cryptographic dependencies for TUI challenge solving)
- `Flask`
- `textual`

## Installation

Clone the repository:

```bash
git clone https://github.com/geniesabbir/youtube-downloader-utils.git
cd youtube-downloader-utils
```

Install `ffmpeg` first.

### macOS

```bash
brew install ffmpeg
```

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y ffmpeg python3-venv
```

## How To Run

### Shell Downloader

```bash
cd youtube_downloader
chmod +x download_lecture.sh
./download_lecture.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

Notes:

- output is saved in the current folder
- the script expects `Homebrew` if it needs to auto-install missing tools on macOS

### Terminal UI

```bash
cd youtube_tui
chmod +x run.sh
./run.sh
```

Manual setup:

```bash
cd youtube_tui
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Output location:

```text
youtube_tui/downloads/
```

### Web UI

```bash
cd youtube_web_ui
chmod +x start.sh
./start.sh
```

Open in your browser:

```text
http://localhost:5001
```

Manual setup:

```bash
cd youtube_web_ui
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Output location:

```text
youtube_web_ui/downloads/
```

## User Agreement

By using this repository, you agree to the following:

- you are responsible for how you use these tools
- you will only download content you own, are authorized to access, or are legally allowed to save
- you understand that platform terms of service may restrict downloading in some situations
- you accept that this repository is provided as-is, without warranty or guarantee of compatibility with every video source or future YouTube change
- you will not use this project for piracy, redistribution of copyrighted material without permission, or any unlawful activity

If you do not agree with these conditions, do not use the software.

## Legal and Usage Disclaimer

This project is provided for educational and personal-use scenarios, especially offline access to legitimately accessible content such as lectures, tutorials, and other permitted media.

The maintainer does not encourage copyright infringement, unauthorized redistribution, or misuse of third-party content. Users are solely responsible for ensuring that their use complies with local law, copyright rules, and the terms of the platforms they access.

## Troubleshooting

### `yt-dlp` fails to download

Update it inside the relevant environment:

```bash
pip install --upgrade yt-dlp
```

### Video and audio do not merge properly

Check that `ffmpeg` is installed and available on your `PATH`:

```bash
ffmpeg -version
```

### `python3` is missing

Install Python 3 and ensure it is available in your shell environment.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Created and maintained by `geniesabbir`.
