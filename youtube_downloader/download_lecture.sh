#!/bin/bash

# YouTube Lecture Downloader
# This script uses yt-dlp and ffmpeg to download videos in the highest possible resolution with clear audio.

echo "========================================"
echo " YouTube Lecture Downloader "
echo "========================================"

# Check if brew is installed
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed. It is required to install dependencies."
    echo "Please install Homebrew by running this command in your terminal first:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# Install dependencies if they don't exist
if ! command -v yt-dlp &> /dev/null; then
    echo "Installing yt-dlp..."
    brew install yt-dlp
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Installing ffmpeg (required for merging high-res video and audio)..."
    brew install ffmpeg
fi

# Check for URL argument
if [ -z "$1" ]; then
    echo ""
    echo "Usage: ./download_lecture.sh <YOUTUBE_URL>"
    echo "Example: ./download_lecture.sh 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    exit 1
fi

URL=$1

echo ""
echo "Starting download for: $URL"
echo "This might take a few minutes depending on your internet connection."
echo "========================================"

# Download using yt-dlp
# We request the best video (mp4 format preferred) and best audio (m4a format preferred),
# and merge them into a single mp4 file. This gives high res (1080p/4k) + clear audio.
yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" --merge-output-format mp4 -o "%(title)s.%(ext)s" "$URL"

echo ""
echo "========================================"
echo "Download finished! The video is saved in your current folder."
