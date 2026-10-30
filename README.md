# YouTube Downloader Utils (Void-Archive)

A collection of lightweight universal media downloader utilities built for offline-first access across desktop, terminal, web, and mobile.

Supported platforms: **YouTube, Facebook, Dailymotion, TikTok, Vimeo, X/Twitter, Instagram, Reddit, Twitch, and 1,800+ sites** supported by `yt-dlp`.

---

## ⚡ Quick Start: One-Click Terminal Install

Install the interactive Terminal UI (**Void-Archive**) into any terminal with zero manual configuration:

### macOS & Linux
```bash
curl -fsSL https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.sh | bash
```

### Windows (PowerShell or Command Prompt)
Open PowerShell (or Command Prompt) and run:
```powershell
irm https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.ps1 | iex
```
*(In Command Prompt `cmd.exe`, you can also paste: `powershell -c "irm https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.ps1 | iex"`)*

### Android (via Termux)
```bash
termux-setup-storage
pkg update && pkg install -y python ffmpeg git
curl -fsSL https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.sh | bash
```

### Local Repository Install
If you have already cloned the repository:
- **macOS / Linux / Termux**: `./install.sh`
- **Windows**: `install.bat` or `.\install.ps1`

Once installed, simply open any terminal window and type:
```bash
void-archive
```
*(or `youtube-tui` / `void`)*

---

## 📖 How to Use the Terminal App (Void-Archive)

### Step 1: Launch
Open any terminal and run:
```bash
void-archive
```

### Step 2: Queue & Discover Videos
1. In the **Queue URLs** input field, paste one or more URLs separated by spaces or commas.
   - Works with single videos, Shorts, reels, clips, or playlists across YouTube, Facebook, TikTok, Vimeo, X, Instagram, etc.
2. Click **ANALYZE URLS** (or press Enter).
3. The app queues the URLs and creates an isolated discovery card for each item with its title, uploader, duration, and platform badge.

### Step 3: Trim Video or Audio (Optional)
If you only need a specific portion, lecture chapter, or clip:
- Enter a **Start** time (e.g., `00:30` or `30` seconds).
- Enter an **End** time (e.g., `02:15` or `135` seconds).
- Leave blank to download the full video.

### Step 4: Download Video or Audio
On any video card, select your format:
- **Download Video**: Downloads best video + audio streams merged into high-quality MP4.
- **Download Audio**: Extracts audio directly to a 192kbps MP3 file.
- Track real-time download progress, transfer speed, and ETA directly on the card's progress bar.
- If a download or discovery encounters a temporary network issue, use **Retry Discover** or **Retry Download** on that specific card.

### Step 5: Handling Bot Checks & Members-Only Content
If a video requires authentication or displays *"Sign in to confirm you're not a bot"*:
1. Under the **Authentication** panel, type or keep your browser name (e.g. `brave`, `chrome`, `firefox`, `edge`).
2. Click **EXPORT COOKIES**.
3. Void-Archive exports your active session into a secure local cache and authenticates your downloads automatically.

---

## 📂 Where Are Files Saved? (Device Download Binding)

Void-Archive automatically binds all downloads directly to your device's native Downloads directory:

| Operating System | Default Download Folder |
| :--- | :--- |
| **macOS** | `~/Downloads` (`/Users/<username>/Downloads`) |
| **Linux** | `~/Downloads` (or XDG Downloads directory) |
| **Android (Termux)** | `/storage/emulated/0/Download` (shows up in Gallery, VLC, Files app) |
| **Windows** | `%USERPROFILE%\Downloads` |

### Custom Download Folder (Optional)
To save downloads into a custom directory, set `VOID_DOWNLOAD_DIR`:
```bash
export VOID_DOWNLOAD_DIR="/path/to/my/folder"
void-archive
```

---

## 🛠️ CLI Management Commands

| Command | Action |
| :--- | :--- |
| `void-archive` | Launch the TUI from any folder |
| `void-archive --dir` | Print the active device download path |
| `void-archive --update` | Update `yt-dlp` and app dependencies in 1 second |
| `void-archive --uninstall` | Cleanly remove Void-Archive and terminal shortcuts |

---

## 📦 Other Included Downloader Experiences

In addition to the Terminal UI, this repository includes:

### 1. Web UI Downloader (`youtube_web_ui/`)
A browser-based Flask web interface:
```bash
cd youtube_web_ui
./start.sh
# Open http://localhost:5001
```

### 2. Native Android App (`youtube_mobile/`)
A cross-platform Flutter mobile application with a graphical touch interface:
```bash
cd youtube_mobile
flutter build apk --release
```
The output APK will be in `build/app/outputs/flutter-apk/app-release.apk`.

### 3. Shell Downloader (`youtube_downloader/`)
A minimal shell script for quick headless downloads:
```bash
cd youtube_downloader
./download_lecture.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

---

## Project Structure

```text
├── install.sh                     # Root one-click installer
├── youtube_tui/                   # Terminal UI application (Void-Archive)
│   ├── app.py                     # Textual UI application
│   ├── downloader.py              # yt-dlp downloader engine & device path resolver
│   ├── install.sh                 # One-click terminal installer
│   ├── requirements.txt           # Dependencies
│   ├── run.sh                     # Local launcher
│   └── style.tcss                 # Terminal CSS styling
├── youtube_web_ui/                # Web UI (Flask)
│   ├── app.py
│   ├── requirements.txt
│   └── start.sh
├── youtube_mobile/                # Android / iOS Flutter App
│   ├── lib/
│   └── pubspec.yaml
└── youtube_downloader/            # Minimal shell downloader
    └── download_lecture.sh
```

---

## Requirements

- `python3` 3.10 or newer
- `ffmpeg` available on `PATH` for merging and extracting audio (automatically installed or verified by `install.sh`)
- Optional: A JavaScript runtime (`deno`, `node`, or `bun`) for YouTube signature decryption challenges

---

## User Agreement

By using this repository, you agree to the following:

- you are responsible for how you use these tools
- you will only download content you own, are authorized to access, or are legally allowed to save
- you understand that platform terms of service may restrict downloading in some situations
- you accept that this repository is provided as-is, without warranty or guarantee of compatibility with every video source or future YouTube change
- you will not use this project for piracy, redistribution of copyrighted material without permission, or any unlawful activity

If you do not agree with these conditions, do not use the software.

---

## Legal and Usage Disclaimer

This project is provided for educational and personal-use scenarios, especially offline access to legitimately accessible content such as lectures, tutorials, and other permitted media.

The maintainer does not encourage copyright infringement, unauthorized redistribution, or misuse of third-party content. Users are solely responsible for ensuring that their use complies with local law, copyright rules, and the terms of the platforms they access.

---

## Troubleshooting

### `yt-dlp` fails to download
Update it inside the environment:
```bash
void-archive --update
```

### Video and audio do not merge properly
Check that `ffmpeg` is installed and available on your `PATH`:
```bash
ffmpeg -version
```

### `python3` is missing
Install Python 3.10+ and ensure it is available in your shell environment.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Created and maintained by `geniesabbir`.
