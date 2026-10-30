# ==============================================================================
# Void-Archive TUI - Windows PowerShell Installer
# https://github.com/geniesabbir/youtube-downloader-utils
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$AppName = "void-archive"
$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$DownloadsDir = Join-Path $env:USERPROFILE "Downloads"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "             VOID-ARCHIVE TUI INSTALLER               " -ForegroundColor Cyan
Write-Host "       Universal Media Downloader for Windows         " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Detect Python
Write-Host "==> Checking for Python 3..." -ForegroundColor Cyan

$PythonExe = $null

if (Get-Command python -ErrorAction SilentlyContinue) {
    try {
        $ver = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        if ($ver -and [version]$ver -ge [version]"3.10") {
            $PythonExe = "python"
        }
    } catch {}
}

if (-not $PythonExe -and (Get-Command py -ErrorAction SilentlyContinue)) {
    try {
        $ver = & py -3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        if ($ver -and [version]$ver -ge [version]"3.10") {
            $PythonExe = "py"
        }
    } catch {}
}

if (-not $PythonExe) {
    Write-Host "Error: Python 3.10 or newer was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "To install Python on Windows, run:" -ForegroundColor Yellow
    Write-Host "    winget install Python.Python.3.12" -ForegroundColor White
    Write-Host "Or download from: https://www.python.org/downloads/" -ForegroundColor White
    Write-Host "Make sure to check 'Add python.exe to PATH' during installation!" -ForegroundColor Yellow
    exit 1
}

$PyVer = if ($PythonExe -eq "py") {
    & py -3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
} else {
    & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
}
Write-Host "✓ Found Python $PyVer ($PythonExe)" -ForegroundColor Green

# 2. Check ffmpeg
Write-Host "==> Checking for ffmpeg..." -ForegroundColor Cyan
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host "✓ Found ffmpeg" -ForegroundColor Green
} else {
    Write-Host "! ffmpeg not found on PATH." -ForegroundColor Yellow
    Write-Host "  (Video stream merging and MP3 audio extraction require ffmpeg)" -ForegroundColor DarkGray
    Write-Host "  Tip: You can easily install it on Windows via winget:" -ForegroundColor Yellow
    Write-Host "      winget install Gyan.FFmpeg" -ForegroundColor White
}

# 3. Create target directories
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
New-Item -ItemType Directory -Force -Path $DownloadsDir | Out-Null

# 4. Determine source and get app files
$IsLocal = $false
$LocalDir = $null

if ($PSScriptRoot) {
    if (Test-Path (Join-Path $PSScriptRoot "app.py")) {
        $IsLocal = $true
        $LocalDir = $PSScriptRoot
    } elseif (Test-Path (Join-Path $PSScriptRoot "youtube_tui\app.py")) {
        $IsLocal = $true
        $LocalDir = Join-Path $PSScriptRoot "youtube_tui"
    }
}

if ($IsLocal) {
    Write-Host "==> Installing from local files ($LocalDir)..." -ForegroundColor Cyan
    Copy-Item -Force (Join-Path $LocalDir "app.py") (Join-Path $InstallDir "app.py")
    Copy-Item -Force (Join-Path $LocalDir "downloader.py") (Join-Path $InstallDir "downloader.py")
    Copy-Item -Force (Join-Path $LocalDir "style.tcss") (Join-Path $InstallDir "style.tcss")
    Copy-Item -Force (Join-Path $LocalDir "requirements.txt") (Join-Path $InstallDir "requirements.txt")
} else {
    Write-Host "==> Downloading latest files from GitHub..." -ForegroundColor Cyan
    $BaseUrl = "https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui"
    $Files = @("app.py", "downloader.py", "style.tcss", "requirements.txt")
    foreach ($f in $Files) {
        $dest = Join-Path $InstallDir $f
        Invoke-WebRequest -Uri "$BaseUrl/$f" -OutFile $dest -UseBasicParsing
    }
}

# 5. Set up Virtual Environment
$VenvDir = Join-Path $InstallDir "venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Host "==> Creating isolated Python virtual environment..." -ForegroundColor Cyan
    if ($PythonExe -eq "py") {
        & py -3 -m venv $VenvDir
    } else {
        & python -m venv $VenvDir
    }
}

Write-Host "==> Installing dependencies (Textual, yt-dlp, mutagen, etc.)..." -ForegroundColor Cyan
& $VenvPython -m pip install --upgrade pip setuptools wheel --quiet 2>$null
& $VenvPython -m pip install -r (Join-Path $InstallDir "requirements.txt") --quiet

# 6. Create Launcher (.cmd and .ps1)
$LauncherCmd = Join-Path $BinDir "void-archive.cmd"
$LauncherPs1 = Join-Path $BinDir "void-archive.ps1"

Write-Host "==> Creating terminal launcher..." -ForegroundColor Cyan

$CmdContent = @"
@echo off
setlocal
set "APP_DIR=$InstallDir"
set "VENV_PY=%APP_DIR%\venv\Scripts\python.exe"

if "%~1"=="--update" (
    echo Updating Void-Archive dependencies and yt-dlp engine...
    "%VENV_PY%" -m pip install --upgrade pip
    "%VENV_PY%" -m pip install --upgrade -r "%APP_DIR%\requirements.txt"
    echo Void-Archive updated successfully!
    exit /b 0
)

if "%~1"=="--dir" (
    "%VENV_PY%" -c "from downloader import YouTubeDownloader; print('Active download folder:', YouTubeDownloader.default_download_path())"
    exit /b 0
)

if "%~1"=="--uninstall" (
    echo Uninstalling Void-Archive...
    if exist "%APP_DIR%" rd /s /q "%APP_DIR%"
    if exist "%USERPROFILE%\.local\bin\void-archive.cmd" del /f /q "%USERPROFILE%\.local\bin\void-archive.cmd"
    if exist "%USERPROFILE%\.local\bin\youtube-tui.cmd" del /f /q "%USERPROFILE%\.local\bin\youtube-tui.cmd"
    if exist "%USERPROFILE%\.local\bin\void.cmd" del /f /q "%USERPROFILE%\.local\bin\void.cmd"
    if exist "%USERPROFILE%\.local\bin\void-archive.ps1" del /f /q "%USERPROFILE%\.local\bin\void-archive.ps1"
    echo Void-Archive has been removed.
    exit /b 0
)

if not exist "%VENV_PY%" (
    echo Error: Python environment not found at %VENV_PY%.
    echo Reinstall via PowerShell:
    echo irm https://raw.githubusercontent.com/geniesabbir/youtube-downloader-utils/main/youtube_tui/install.ps1 ^| iex
    exit /b 1
)

cd /d "%APP_DIR%"
"%VENV_PY%" "%APP_DIR%\app.py" %*
"@

Set-Content -Path $LauncherCmd -Value $CmdContent -Encoding ASCII

# Aliases
Copy-Item -Force $LauncherCmd (Join-Path $BinDir "youtube-tui.cmd")
Copy-Item -Force $LauncherCmd (Join-Path $BinDir "void.cmd")

# 7. Configure User PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$PathAdded = $false

if ($UserPath -notlike "*$BinDir*") {
    Write-Host "==> Adding $BinDir to User PATH..." -ForegroundColor Cyan
    $NewPath = if ($UserPath) { "$UserPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    $PathAdded = $true
}

# Update current process PATH
if ($env:Path -notlike "*$BinDir*") {
    $env:Path = "$env:Path;$BinDir"
}

# 8. Success Output
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " [OK] Void-Archive Installation Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Run command:        void-archive  (or youtube-tui / void)" -ForegroundColor Cyan
Write-Host "  Downloads bound to: $DownloadsDir" -ForegroundColor White
Write-Host "  Installed at:       $InstallDir" -ForegroundColor DarkGray
Write-Host ""
if ($PathAdded) {
    Write-Host "  NOTE: PATH was updated. If 'void-archive' is not recognized in an existing" -ForegroundColor Yellow
    Write-Host "  Command Prompt window, please restart that terminal or open PowerShell." -ForegroundColor Yellow
    Write-Host ""
}
Write-Host "  Options:" -ForegroundColor DarkGray
Write-Host "    void-archive --update      Update yt-dlp & app dependencies" -ForegroundColor DarkGray
Write-Host "    void-archive --dir         Show the active download folder" -ForegroundColor DarkGray
Write-Host "    void-archive --uninstall   Completely remove Void-Archive" -ForegroundColor DarkGray
Write-Host ""
