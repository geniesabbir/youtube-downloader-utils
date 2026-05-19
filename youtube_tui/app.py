from textual.app import App, ComposeResult
from textual.containers import Container, Vertical, Horizontal
from textual.widgets import Header, Footer, Input, Button, Label, ProgressBar, RadioSet, RadioButton, Static
from textual.binding import Binding
from textual import work, on
import asyncio
from downloader import YouTubeDownloader
import os

class YouTubeTUI(App):
    CSS_PATH = "style.tcss"
    TITLE = "VOID-ARCHIVE v2.0"
    SUB_TITLE = "Single Column Mode"

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Vertical(id="workspace"):
            yield Static("SYSTEM READY", id="system-status")
            
            with Vertical(id="input-panel"):
                yield Label("VIDEO LINK")
                yield Input(placeholder="Paste your YouTube link here...", id="url-input")
                yield Button("FIND VIDEO", variant="success", id="analyze-btn")

            with Vertical(id="metadata-panel"):
                yield Label("VIDEO INFORMATION", classes="panel-header")
                yield Static("Title: [dim]Scanning...[/dim]", id="meta-title")
                yield Static("Channel: [dim]Scanning...[/dim]", id="meta-author")
                
                yield Label("SELECT FORMAT", classes="panel-header")
                with RadioSet(id="quality-selector"):
                    yield RadioButton("High Quality Video (MP4)", id="video-high", value=True)
                    yield RadioButton("Audio Only (MP3)", id="audio-only")
                
                yield Button("DOWNLOAD NOW", id="download-btn")

            with Vertical(id="execution-panel"):
                yield Label("DOWNLOAD PROGRESS", classes="panel-header")
                yield ProgressBar(id="main-progress", show_eta=True, show_percentage=True)
                yield Static("Waiting to start...", id="detailed-status")
        
        yield Footer()

    @on(Button.Pressed, "#analyze-btn")
    @work(exclusive=True)
    async def handle_analyze(self) -> None:
        url = self.query_one("#url-input").value
        if not url: 
            self.notify("Please paste a link first!", severity="warning")
            return

        self.notify("Looking for video details...")
        btn = self.query_one("#analyze-btn")
        btn.disabled = True
        btn.label = "SEARCHING..."
        
        downloader = YouTubeDownloader()
        loop = asyncio.get_event_loop()
        meta = await loop.run_in_executor(None, downloader.get_metadata, url)
        
        if meta and 'error' not in meta:
            self.query_one("#meta-title").update(f"Title: [bold]{meta['title']}[/bold]")
            self.query_one("#meta-author").update(f"From: [bold]{meta['author']}[/bold]")
            self.notify("Video found!")
        elif meta and 'error' in meta:
            self.notify(f"Error: {meta['error'][:50]}", severity="error")
        else:
            self.notify("Could not find video info.", severity="error")
        
        btn.disabled = False
        btn.label = "FIND VIDEO"

    @on(Button.Pressed, "#download-btn")
    @work(exclusive=True)
    async def handle_download(self) -> None:
        url = self.query_one("#url-input").value
        if not url: return

        quality = "best" if self.query_one("#video-high").value else "audio"
        
        self.query_one("#download-btn").disabled = True
        self.query_one("#main-progress").progress = 0
        self.update_status("Starting download...")
        self.notify("Starting download...")
        
        downloader = YouTubeDownloader(progress_callback=self.update_progress)
        loop = asyncio.get_event_loop()
        
        try:
            self.update_status("Preparing files...")
            success, message = await loop.run_in_executor(None, downloader.download, url, quality)
            
            if success:
                self.notify("Download Successful!", severity="information")
                self.update_status("SUCCESS: Saved to downloads/")
            else:
                self.notify(f"Failed: {message}", severity="error")
                self.update_status("DOWNLOAD FAILED")
        except Exception as e:
            self.notify(f"Error: {str(e)}", severity="error")
            self.update_status("SYSTEM ERROR")
            
        self.query_one("#download-btn").disabled = False

    def update_progress(self, d: dict) -> None:
        if d['status'] == 'downloading':
            try:
                downloaded = d.get('downloaded_bytes', 0)
                total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
                
                if total > 0:
                    progress = (downloaded / total) * 100
                    speed = d.get('_speed_str', 'N/A')
                    eta = d.get('_eta_str', 'N/A')
                    
                    filename = d.get('filename', '').lower()
                    mode = "Video Stream"
                    if ".m4a" in filename or "audio" in filename:
                        mode = "Audio Stream"
                    
                    self.call_from_thread(self.safe_update, progress, f"{mode}: {speed} | ETA: {eta}")
            except Exception:
                pass
        elif d['status'] == 'processing':
            action = d.get('action', 'Processing')
            if action == 'merging':
                self.call_from_thread(self.safe_update, 100, "Merging Video & Audio (FFmpeg)...")
            elif action == 'finished':
                self.call_from_thread(self.safe_update, 100, "Finalizing files...")
        elif d['status'] == 'finished':
            pass

    def safe_update(self, progress: float, status: str):
        try:
            bar = self.query_one("#main-progress")
            bar.total = 100
            bar.progress = progress
            self.query_one("#detailed-status").update(status)
        except Exception:
            pass

    def update_status(self, text: str):
        self.query_one("#detailed-status").update(text)

if __name__ == "__main__":
    app = YouTubeTUI()
    app.run()
