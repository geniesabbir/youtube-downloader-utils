#!/usr/bin/env bash
# ==============================================================================
# Void-Archive TUI - Root Installer Entrypoint
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

if [ -f "$SCRIPT_DIR/youtube_tui/install.sh" ]; then
    exec bash "$SCRIPT_DIR/youtube_tui/install.sh" "$@"
else
    # Fallback if downloaded standalone
    exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.sh)" -- "$@"
fi
