# Void-Downloader Web UI

Small Flask-based web UI for fetching YouTube media information and downloading video or audio with `yt-dlp`.

## Requirements

Before running the project, make sure these are installed on your machine:

- `python3`
- `cloudflared` if you want to use the tunnel command

## Quick Start

From the project folder, run:

```bash
./run dev
```

Then open:

```text
http://127.0.0.1:5001
```

## Available Commands

### Development

```bash
./run dev
```

Starts the app with Flask debug mode enabled.

### Local Production-Style Run

```bash
./run prod
```

Starts the app with debug mode disabled.

Note: this is a local production-style run, not a full production deployment stack.

### Production-Style Run + Cloudflare Tunnel

```bash
./run cloudflared
```

Starts the app locally, then opens a Cloudflare tunnel and prints a public URL you can share.

## What Happens Automatically

When you run any of the commands above, the `run` script will:

- create a `venv` automatically if it does not exist
- install Python packages from `requirements.txt`
- start the application

This means a new user does not need to manually run:

```bash
python3 -m venv venv
pip install -r requirements.txt
```

## Optional Environment Variables

You can override the default host and port:

```bash
HOST=127.0.0.1 PORT=5001 ./run dev
```

Examples:

```bash
PORT=8000 ./run dev
PORT=8000 ./run prod
PORT=8000 ./run cloudflared
```

## Bare `run` Command

If you want to type:

```bash
run dev
run prod
run cloudflared
```

instead of:

```bash
./run dev
./run prod
./run cloudflared
```

add this alias to your `~/.zshrc`:

```bash
alias run="/Users/genie-sabbir/Documents/antigravity/game_dev/youtube_web_ui/run"
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Installed Python Packages

This project currently uses:

- `Flask==3.0.3`
- `yt-dlp==2026.3.17`

## Troubleshooting

### `python3: command not found`

Install Python 3 first, then rerun the command.

### `cloudflared is not installed`

Install `cloudflared` first, then rerun:

```bash
./run cloudflared
```

### Port already in use

Run on a different port:

```bash
PORT=8000 ./run dev
```
