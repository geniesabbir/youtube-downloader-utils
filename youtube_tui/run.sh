#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
export PIP_DISABLE_PIP_VERSION_CHECK=1

echo "======================================"
echo " Starting Void-Archive TUI "
echo "======================================"

UPDATE_MODE=0
if [ "${1:-}" = "--update" ]; then
    UPDATE_MODE=1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required but was not found."
    exit 1
fi

if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "Activating environment..."
source venv/bin/activate

if [ "$UPDATE_MODE" -eq 1 ]; then
    echo "Update mode enabled. Refreshing packaging tools..."
    python3 -m pip install --upgrade pip setuptools wheel > /dev/null
    echo "Updating pinned application dependencies..."
    python3 -m pip install --upgrade -r requirements.txt > /dev/null
else
    echo "Installing pinned application dependencies..."
    python3 -m pip install -r requirements.txt > /dev/null
    echo "Tip: use ./run.sh --update when you intentionally want dependency upgrades."
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "ffmpeg not found. Attempting Homebrew install..."
        brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
    else
        echo "Warning: ffmpeg is not installed and Homebrew is unavailable."
        echo "Video merge and MP3 extraction may fail until ffmpeg is installed."
    fi
fi

COOKIE_STATUS_RESULT="$(python3 - <<'PY'
from downloader import YouTubeDownloader
state = YouTubeDownloader.auth_status()
print(f"AUTH_ENABLED={int(bool(state.get('enabled')))}")
print(f"AUTH_REFRESH_REASON={state.get('refresh_reason', '')}")
print(f"AUTH_DETAIL={state.get('detail', '')}")
PY
)"

COOKIE_ENABLED="$(printf '%s\n' "$COOKIE_STATUS_RESULT" | sed -n 's/^AUTH_ENABLED=//p')"
COOKIE_REFRESH_REASON="$(printf '%s\n' "$COOKIE_STATUS_RESULT" | sed -n 's/^AUTH_REFRESH_REASON=//p')"
COOKIE_DETAIL="$(printf '%s\n' "$COOKIE_STATUS_RESULT" | sed -n 's/^AUTH_DETAIL=//p')"

if [ -n "${YTDLP_COOKIES_FILE:-}" ]; then
    echo "Using explicit cookie file from environment."
elif [ "$COOKIE_ENABLED" = "1" ] && [ -z "$COOKIE_REFRESH_REASON" ]; then
    echo "Using existing cached signed-in cookie session."
else
    echo "No valid cached cookie session detected."
    if [ -n "$COOKIE_DETAIL" ]; then
        echo "$COOKIE_DETAIL"
    fi
    echo "Scanning supported browsers for a signed-in YouTube session..."
    AUTO_COOKIE_RESULT="$(python3 - <<'PY'
from downloader import YouTubeDownloader

success, message, browser_spec, cookie_path = YouTubeDownloader.auto_export_cookies()
status = "SUCCESS" if success else "FAILED"
print(f"AUTO_COOKIE_STATUS={status}")
print(f"AUTO_COOKIE_BROWSER={browser_spec or ''}")
print(f"AUTO_COOKIE_PATH={cookie_path or ''}")
print(f"AUTO_COOKIE_MESSAGE={message}")
PY
)"

    AUTO_COOKIE_STATUS="$(printf '%s\n' "$AUTO_COOKIE_RESULT" | sed -n 's/^AUTO_COOKIE_STATUS=//p')"
    AUTO_COOKIE_BROWSER="$(printf '%s\n' "$AUTO_COOKIE_RESULT" | sed -n 's/^AUTO_COOKIE_BROWSER=//p')"
    AUTO_COOKIE_PATH="$(printf '%s\n' "$AUTO_COOKIE_RESULT" | sed -n 's/^AUTO_COOKIE_PATH=//p')"
    AUTO_COOKIE_MESSAGE="$(printf '%s\n' "$AUTO_COOKIE_RESULT" | sed -n 's/^AUTO_COOKIE_MESSAGE=//p')"

    if [ "$AUTO_COOKIE_STATUS" = "SUCCESS" ]; then
        export YTDLP_COOKIES_FILE="$AUTO_COOKIE_PATH"
        echo "Using signed-in browser cookies from: $AUTO_COOKIE_BROWSER"
    else
        echo "No signed-in browser cookie export available."
        echo "$AUTO_COOKIE_MESSAGE"
    fi
fi

echo "Launching terminal app..."
python3 app.py
