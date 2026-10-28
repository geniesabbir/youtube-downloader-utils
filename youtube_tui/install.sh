#!/usr/bin/env bash
# ==============================================================================
# Void-Archive TUI - Universal One-Click Terminal Installer
# https://github.com/geniesabbir/youtube-downloader-utils
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m' # No Color

APP_NAME="void-archive"
REPO_URL="https://github.com/geniesabbir/youtube-downloader-utils.git"
INSTALL_DIR="${HOME}/.local/share/${APP_NAME}"
BIN_DIR="${HOME}/.local/bin"
DOWNLOADS_DIR="${HOME}/Downloads"

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║             VOID-ARCHIVE TUI INSTALLER               ║"
echo "║          Universal Media Downloader for CLI          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 1. Detect Source (Local Clone vs Remote Curl)
SCRIPT_SOURCE=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
fi

IS_LOCAL_INSTALL=0
LOCAL_APP_DIR=""

if [ -n "$SCRIPT_SOURCE" ]; then
    if [ -f "$SCRIPT_SOURCE/app.py" ] && [ -f "$SCRIPT_SOURCE/downloader.py" ]; then
        IS_LOCAL_INSTALL=1
        LOCAL_APP_DIR="$SCRIPT_SOURCE"
    elif [ -f "$SCRIPT_SOURCE/youtube_tui/app.py" ] && [ -f "$SCRIPT_SOURCE/youtube_tui/downloader.py" ]; then
        IS_LOCAL_INSTALL=1
        LOCAL_APP_DIR="$SCRIPT_SOURCE/youtube_tui"
    fi
fi

# 2. Check Python 3
echo -e "${CYAN}==>${NC} Checking Python 3..."
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Error: python3 is required but not installed.${NC}"
    if [[ "${OSTYPE:-}" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
        echo "Attempting to install python3 using Homebrew..."
        brew install python3
    else
        echo "Please install Python 3.10 or newer from https://python.org or your package manager."
        exit 1
    fi
fi

PYTHON_BIN="$(command -v python3)"
PY_VER="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
echo -e "${GREEN}✓ Found Python ${PY_VER} (${PYTHON_BIN})${NC}"

# 3. Check venv support
if ! "$PYTHON_BIN" -c "import venv" >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: python3-venv is missing.${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        echo "Attempting to install python3-venv..."
        sudo apt-get update && sudo apt-get install -y python3-venv || true
    fi
fi

# 4. Check ffmpeg (media merging & audio extraction)
echo -e "${CYAN}==>${NC} Checking ffmpeg..."
if command -v ffmpeg >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Found ffmpeg${NC}"
else
    echo -e "${YELLOW}! ffmpeg not found.${NC}"
    if [[ "${OSTYPE:-}" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
        echo "Installing ffmpeg via Homebrew (this may take a moment)..."
        brew install ffmpeg || echo "Note: ffmpeg install skipped or failed; continuing..."
    elif command -v apt-get >/dev/null 2>&1; then
        echo -e "${DIM}Tip: You can install ffmpeg later with: sudo apt-get install ffmpeg${NC}"
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${DIM}Tip: You can install ffmpeg later with: sudo dnf install ffmpeg${NC}"
    fi
fi

# 5. Prepare Target Application Directory
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$DOWNLOADS_DIR"

if [ "$IS_LOCAL_INSTALL" -eq 1 ]; then
    echo -e "${CYAN}==>${NC} Installing from local repository ($LOCAL_APP_DIR)..."
    cp -f "$LOCAL_APP_DIR/app.py" "$INSTALL_DIR/"
    cp -f "$LOCAL_APP_DIR/downloader.py" "$INSTALL_DIR/"
    cp -f "$LOCAL_APP_DIR/style.tcss" "$INSTALL_DIR/"
    cp -f "$LOCAL_APP_DIR/requirements.txt" "$INSTALL_DIR/"
else
    echo -e "${CYAN}==>${NC} Downloading latest Void-Archive from GitHub..."
    if command -v git >/dev/null 2>&1; then
        TMP_CLONE_DIR="$(mktemp -d -t void_archive_XXXXXX 2>/dev/null || mktemp -d)"
        git clone --depth 1 --quiet "$REPO_URL" "$TMP_CLONE_DIR"
        cp -f "$TMP_CLONE_DIR/youtube_tui/app.py" "$INSTALL_DIR/"
        cp -f "$TMP_CLONE_DIR/youtube_tui/downloader.py" "$INSTALL_DIR/"
        cp -f "$TMP_CLONE_DIR/youtube_tui/style.tcss" "$INSTALL_DIR/"
        cp -f "$TMP_CLONE_DIR/youtube_tui/requirements.txt" "$INSTALL_DIR/"
        rm -rf "$TMP_CLONE_DIR"
    else
        echo -e "${CYAN}==>${NC} Downloading via curl archive..."
        curl -fsSL "https://github.com/geniesabbir/youtube-downloader-utils/archive/refs/heads/main.tar.gz" | \
            tar -xz -C "$INSTALL_DIR" --strip-components=2 "youtube-downloader-utils-main/youtube_tui"
    fi
fi

# 6. Setup Isolated Virtual Environment
echo -e "${CYAN}==>${NC} Setting up isolated Python environment..."
if [ ! -d "$INSTALL_DIR/venv" ]; then
    "$PYTHON_BIN" -m venv "$INSTALL_DIR/venv"
fi

"$INSTALL_DIR/venv/bin/python3" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true

echo -e "${CYAN}==>${NC} Installing dependencies (Textual, yt-dlp, mutagen, etc.)..."
"$INSTALL_DIR/venv/bin/python3" -m pip install -r "$INSTALL_DIR/requirements.txt" >/dev/null

# 7. Create Global Executable Launcher
LAUNCHER_PATH="$BIN_DIR/void-archive"
echo -e "${CYAN}==>${NC} Creating terminal command: ${BOLD}void-archive${NC}..."

cat << 'EOF' > "$LAUNCHER_PATH"
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${HOME}/.local/share/void-archive"
VENV_PYTHON="${APP_DIR}/venv/bin/python3"
export PIP_DISABLE_PIP_VERSION_CHECK=1
export VOID_DOWNLOAD_DIR="${VOID_DOWNLOAD_DIR:-$HOME/Downloads}"

if [ "${1:-}" = "--update" ]; then
    echo "Updating Void-Archive dependencies and yt-dlp engine..."
    "$VENV_PYTHON" -m pip install --upgrade pip
    "$VENV_PYTHON" -m pip install --upgrade -r "${APP_DIR}/requirements.txt"
    echo "✓ Void-Archive updated successfully!"
    exit 0
fi

if [ "${1:-}" = "--dir" ]; then
    echo "Active download folder: ${VOID_DOWNLOAD_DIR}"
    exit 0
fi

if [ "${1:-}" = "--uninstall" ]; then
    echo "Uninstalling Void-Archive..."
    rm -rf "${APP_DIR}"
    rm -f "${HOME}/.local/bin/void-archive" "${HOME}/.local/bin/youtube-tui" "${HOME}/.local/bin/void"
    echo "✓ Void-Archive has been completely removed."
    exit 0
fi

if [ ! -f "${VENV_PYTHON}" ]; then
    echo "Error: Virtual environment not found in ${APP_DIR}."
    echo "Reinstall using: curl -fsSL https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.sh | bash"
    exit 1
fi

cd "${APP_DIR}"

# Scan cookies if none currently active
COOKIE_STATUS_RESULT="$("${VENV_PYTHON}" - <<'PY'
from downloader import YouTubeDownloader
state = YouTubeDownloader.auth_status()
print(f"AUTH_ENABLED={int(bool(state.get('enabled')))}")
print(f"AUTH_REFRESH_REASON={state.get('refresh_reason', '')}")
PY
)"
COOKIE_ENABLED="$(printf '%s\n' "$COOKIE_STATUS_RESULT" | sed -n 's/^AUTH_ENABLED=//p')"
COOKIE_REFRESH_REASON="$(printf '%s\n' "$COOKIE_STATUS_RESULT" | sed -n 's/^AUTH_REFRESH_REASON=//p')"

if [ -z "${YTDLP_COOKIES_FILE:-}" ] && [ "$COOKIE_ENABLED" != "1" ]; then
    AUTO_COOKIE_RESULT="$("${VENV_PYTHON}" - <<'PY'
from downloader import YouTubeDownloader
success, message, browser_spec, cookie_path = YouTubeDownloader.auto_export_cookies()
if success and cookie_path:
    print(f"AUTO_COOKIE_PATH={cookie_path}")
PY
)"
    AUTO_COOKIE_PATH="$(printf '%s\n' "$AUTO_COOKIE_RESULT" | sed -n 's/^AUTO_COOKIE_PATH=//p')"
    if [ -n "$AUTO_COOKIE_PATH" ]; then
        export YTDLP_COOKIES_FILE="$AUTO_COOKIE_PATH"
    fi
fi

exec "${VENV_PYTHON}" "${APP_DIR}/app.py" "$@"
EOF

chmod +x "$LAUNCHER_PATH"

# Create friendly aliases
ln -sf "$LAUNCHER_PATH" "$BIN_DIR/youtube-tui"
ln -sf "$LAUNCHER_PATH" "$BIN_DIR/void"

# 8. Configure Shell PATH if needed
PATH_ALREADY_INCLUDED=0
case ":$PATH:" in
    *":$BIN_DIR:"*) PATH_ALREADY_INCLUDED=1 ;;
esac

CONFIGURED_SHELL_FILE=""
if [ "$PATH_ALREADY_INCLUDED" -eq 0 ]; then
    EXPORT_STR='export PATH="$HOME/.local/bin:$PATH"'
    
    # Check current shell and common profile files
    CURRENT_SHELL="$(basename "${SHELL:-bash}")"
    if [ "$CURRENT_SHELL" = "zsh" ] || [ -f "$HOME/.zshrc" ]; then
        if ! grep -qs '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo '# Void-Archive / Local CLI tools' >> "$HOME/.zshrc"
            echo "$EXPORT_STR" >> "$HOME/.zshrc"
            CONFIGURED_SHELL_FILE="$HOME/.zshrc"
        fi
    fi

    if [ "$CURRENT_SHELL" = "bash" ] || [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ]; then
        for b_rc in "$HOME/.bashrc" "$HOME/.bash_profile"; do
            if [ -f "$b_rc" ] && ! grep -qs '\.local/bin' "$b_rc" 2>/dev/null; then
                echo "" >> "$b_rc"
                echo "$EXPORT_STR" >> "$b_rc"
                CONFIGURED_SHELL_FILE="${CONFIGURED_SHELL_FILE:-$b_rc}"
            fi
        done
    fi

    if [ -d "$HOME/.config/fish" ]; then
        FISH_CONF="$HOME/.config/fish/config.fish"
        if [ -f "$FISH_CONF" ] && ! grep -qs '\.local/bin' "$FISH_CONF" 2>/dev/null; then
            echo 'set -gx PATH $HOME/.local/bin $PATH' >> "$FISH_CONF"
            CONFIGURED_SHELL_FILE="${CONFIGURED_SHELL_FILE:-$FISH_CONF}"
        fi
    fi
fi

# 9. Finished banner
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD} ✓ Installation Complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Run command:${NC}      ${CYAN}${BOLD}void-archive${NC}   (or ${CYAN}youtube-tui${NC} / ${CYAN}void${NC})"
echo -e "  ${BOLD}Downloads bound to:${NC} ${GREEN}${BOLD}${DOWNLOADS_DIR}${NC}"
echo -e "  ${BOLD}Installed at:${NC}     ${DIM}${INSTALL_DIR}${NC}"
echo ""
if [ "$PATH_ALREADY_INCLUDED" -eq 0 ] && [ -n "$CONFIGURED_SHELL_FILE" ]; then
    echo -e "  ${YELLOW}Notice:${NC} $BIN_DIR was added to ${CONFIGURED_SHELL_FILE}."
    echo -e "  To start right now in this current terminal session, run:"
    echo -e "      ${BOLD}source ${CONFIGURED_SHELL_FILE}${NC}  or  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
fi
echo -e "  ${DIM}Options:${NC}"
echo -e "    void-archive --update      Update yt-dlp & app dependencies"
echo -e "    void-archive --dir         Show the active download folder"
echo -e "    void-archive --uninstall   Completely remove Void-Archive"
echo ""
