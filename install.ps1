# ==============================================================================
# Void-Archive TUI - Windows Root Installer Entrypoint
# ==============================================================================
[CmdletBinding()]
param()

$ScriptDir = $PSScriptRoot

if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir "youtube_tui\install.ps1"))) {
    & (Join-Path $ScriptDir "youtube_tui\install.ps1") @args
} else {
    Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.ps1")
}
