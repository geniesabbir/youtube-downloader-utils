from __future__ import annotations

import asyncio
import os
import re
from dataclasses import dataclass

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import Button, Footer, Header, Input, Label, ProgressBar, Static

from downloader import YouTubeDownloader


@dataclass
class VideoJobState:
    job_id: str
    source_url: str
    target_url: str
    title: str = "Pending discovery"
    author: str = "Unknown"
    duration: str = "N/A"
    platform: str = "Media"
    status: str = "Queued for discovery"
    discovered: bool = False
    discover_failed: bool = False
    download_failed: bool = False
    downloading: bool = False
    last_download_mode: str | None = None
    progress: float = 0.0
    is_members_only: bool = False
    trim_start: str | None = None
    trim_end: str | None = None


class VideoCard(Static):
    def __init__(self, state: VideoJobState) -> None:
        super().__init__(id=f"video-card-{state.job_id}", classes="video-card")
        self.state = state

    def compose(self) -> ComposeResult:
        yield Static(f"JOB {self.state.job_id}", classes="video-kicker")
        yield Label(self.state.title, id=f"title-{self.state.job_id}", classes="video-title")
        yield Static(self._meta_text(), id=f"meta-{self.state.job_id}", classes="video-meta")
        yield Static(self._status_text(), id=f"status-{self.state.job_id}", classes="video-status")

        yield ProgressBar(
            total=100,
            show_eta=False,
            show_percentage=True,
            id=f"progress-{self.state.job_id}",
        )
        with Horizontal(classes="trim-container"):
            yield Static("Trim Range (Optional):", classes="trim-label")
            yield Input(placeholder="Start e.g. 00:30", id=f"trim-start-{self.state.job_id}", classes="trim-input")
            yield Input(placeholder="End e.g. 02:15", id=f"trim-end-{self.state.job_id}", classes="trim-input")
        with Horizontal(classes="video-actions"):
            yield Button("Retry Discover", id=f"retry-discover-{self.state.job_id}", variant="warning")
            yield Button("Download Video", id=f"download-video-{self.state.job_id}", variant="success")
            yield Button("Download Audio", id=f"download-audio-{self.state.job_id}", variant="primary")
            yield Button("Retry Download", id=f"retry-download-{self.state.job_id}", variant="error")

    def on_mount(self) -> None:
        self.apply_state(self.state)

    def apply_state(self, state: VideoJobState) -> None:
        self.state = state
        self.query_one(f"#title-{state.job_id}", Label).update(state.title)
        self.query_one(f"#meta-{state.job_id}", Static).update(self._meta_text())
        self.query_one(f"#status-{state.job_id}", Static).update(self._status_text())

        if state.is_members_only:
            self.add_class("members-only")
        else:
            self.remove_class("members-only")

        trim_start = self.query_one(f"#trim-start-{state.job_id}", Input)
        trim_end = self.query_one(f"#trim-end-{state.job_id}", Input)

        if state.trim_start is not None and trim_start.value != state.trim_start:
            trim_start.value = state.trim_start
        if state.trim_end is not None and trim_end.value != state.trim_end:
            trim_end.value = state.trim_end

        trim_start.disabled = not state.discovered or state.downloading
        trim_end.disabled = not state.discovered or state.downloading

        progress = self.query_one(f"#progress-{state.job_id}", ProgressBar)
        progress.total = 100
        progress.progress = state.progress

        retry_discover = self.query_one(f"#retry-discover-{state.job_id}", Button)
        download_video = self.query_one(f"#download-video-{state.job_id}", Button)
        download_audio = self.query_one(f"#download-audio-{state.job_id}", Button)
        retry_download = self.query_one(f"#retry-download-{state.job_id}", Button)

        retry_discover.disabled = not state.discover_failed or state.downloading
        download_ready = state.discovered and not state.downloading
        download_video.disabled = not download_ready
        download_audio.disabled = not download_ready
        retry_download.disabled = not state.download_failed or state.downloading

    def _meta_text(self) -> str:
        return (
            f"Platform: [bold cyan]{self.state.platform}[/bold cyan]  •  Creator: [bold]{self.state.author}[/bold]\n"
            f"Duration: [bold]{self.state.duration}[/bold]\n"
            f"URL: [dim]{self.state.target_url}[/dim]"
        )

    def _status_text(self) -> str:
        return f"Status: [bold]{self.state.status}[/bold]"


class YouTubeTUI(App):
    CSS_PATH = "style.tcss"
    TITLE = "VOID-ARCHIVE v3.0"
    SUB_TITLE = "Universal Media Downloader"

    def __init__(self) -> None:
        super().__init__()
        self.jobs: dict[str, VideoJobState] = {}
        self.job_counter = 0
        self.auth_state = YouTubeDownloader.auth_status()

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with VerticalScroll(id="workspace"):
            with Horizontal(id="topbar", classes="app-card"):
                with Vertical(id="title-block"):
                    yield Static("VOID ARCHIVE", classes="eyebrow")
                    yield Label("Universal Media Downloader", id="hero-title")
                    yield Static(
                        "Download from YouTube, Facebook, Dailymotion, TikTok, Vimeo, X/Twitter, Instagram & 1,800+ sites.",
                        id="hero-copy",
                    )
                with Vertical(id="status-block"):
                    yield Static("SESSION", classes="mini-label")
                    yield Static("SYSTEM READY", id="system-status")

            with Vertical(id="auth-panel", classes="app-card"):
                yield Static("AUTHENTICATION", classes="eyebrow")
                yield Label("Cookie session", classes="section-title")
                yield Static(self._auth_status_text(), id="auth-status")
                with Horizontal(id="auth-actions"):
                    yield Input(
                        value=self._default_browser_spec(),
                        placeholder="Browser spec, e.g. brave or chrome:Profile 1",
                        id="browser-spec-input",
                    )
                    yield Button("EXPORT COOKIES", variant="primary", id="export-cookies-btn")

            with Vertical(id="input-panel", classes="app-card"):
                yield Static("DISCOVERY", classes="eyebrow")
                yield Label("Queue URLs", classes="section-title")
                yield Static(
                    "Supported: YouTube, Facebook, Dailymotion, TikTok, Vimeo, X/Twitter, Instagram, Reddit, Twitch & 1,800+ sites.",
                    id="sources-hint",
                )
                with Horizontal(id="discover-actions"):
                    yield Input(
                        placeholder="Paste URLs (YouTube, Facebook, Dailymotion, TikTok, Vimeo, etc.)...",
                        id="url-input",
                    )
                    yield Button("ANALYZE URLS", variant="success", id="analyze-btn")

            with Vertical(id="results-panel", classes="app-card"):
                yield Static("RESULTS", classes="eyebrow")
                yield Label("Discovered videos", classes="section-title")
                yield Static(
                    "Each successful discovery becomes its own download card.",
                    id="results-summary",
                )
                with Vertical(id="results-list"):
                    yield Static(
                        "No discovery jobs yet.\nStart with a URL batch above.",
                        id="empty-state",
                    )

        yield Footer()

    def on_mount(self) -> None:
        self.refresh_auth_status()

    @on(Input.Submitted, "#url-input")
    async def handle_url_submitted(self) -> None:
        await self.handle_analyze()

    @on(Input.Submitted, "#browser-spec-input")
    async def handle_browser_spec_submitted(self) -> None:
        await self.handle_export_cookies()

    @on(Button.Pressed, "#analyze-btn")
    async def handle_analyze(self) -> None:
        self.refresh_auth_status()
        refresh_reason = self.auth_state.get("refresh_reason")
        if refresh_reason in {"expired", "missing", "unauthenticated"}:
            self.notify(
                "Notice: Signed-in cookie session is inactive. Proceeding with public access.",
                severity="information",
            )
        elif refresh_reason == "expiring_soon":
            self.notify("Cookies are expiring soon. Re-export is recommended.", severity="warning")

        raw_value = self.query_one("#url-input", Input).value
        urls = self.parse_urls(raw_value)
        if not urls:
            self.notify("Paste at least one valid URL first.", severity="warning")
            return

        await self.reset_results()
        self.query_one("#analyze-btn", Button).disabled = True
        self.update_summary(f"Running discovery for {len(urls)} URL(s)...")

        for url in urls:
            job = self.create_job(source_url=url, target_url=url, status="Discovering video details...")
            await self.mount_card(job)
            asyncio.create_task(self.discover_source(job.job_id, url))

    @on(Button.Pressed, "#export-cookies-btn")
    async def handle_export_cookies(self) -> None:
        browser_spec = self.query_one("#browser-spec-input", Input).value.strip()
        if not browser_spec:
            self.notify("Enter a browser spec first.", severity="warning")
            return

        button = self.query_one("#export-cookies-btn", Button)
        button.disabled = True
        self.query_one("#system-status", Static).update("EXPORTING COOKIES...")

        loop = asyncio.get_running_loop()
        downloader = YouTubeDownloader()
        success, message, cookie_path = await loop.run_in_executor(
            None,
            downloader.export_cookies,
            browser_spec,
        )

        button.disabled = False
        if success:
            os.environ["YTDLP_COOKIES_FILE"] = cookie_path
            self.refresh_auth_status()
            if self.auth_state.get("enabled"):
                self.query_one("#system-status", Static).update(
                    f"COOKIE SESSION READY"
                )
                self.notify(
                    f"Signed-in cookies exported: {cookie_path}",
                    severity="information",
                )
            else:
                self.query_one("#system-status", Static).update(
                    "EXPORT COMPLETE, SIGN-IN NOT DETECTED"
                )
                self.notify(
                    "Cookies were exported, but no active signed-in session was detected in the specified browser profile.",
                    severity="warning",
                )
        else:
            self.query_one("#system-status", Static).update("COOKIE EXPORT FAILED")
            self.notify(message, severity="error")

    @on(Button.Pressed)
    async def handle_dynamic_actions(self, event: Button.Pressed) -> None:
        button_id = event.button.id or ""
        if button_id == "analyze-btn":
            return
        if button_id.startswith("retry-discover-"):
            await self.retry_discover(button_id.removeprefix("retry-discover-"))
            return
        if button_id.startswith("download-video-"):
            job_id = button_id.removeprefix("download-video-")
            await self.start_download(job_id, "video:best")
            return
        if button_id.startswith("download-audio-"):
            job_id = button_id.removeprefix("download-audio-")
            await self.start_download(job_id, "audio:best")
            return
        if button_id.startswith("retry-download-"):
            job_id = button_id.removeprefix("retry-download-")
            job = self.jobs.get(job_id)
            if job and job.last_download_mode:
                await self.start_download(job_id, job.last_download_mode)





    async def retry_discover(self, job_id: str) -> None:
        job = self.jobs.get(job_id)
        if not job:
            return

        job.discover_failed = False
        job.is_members_only = False
        job.status = "Retrying discovery..."
        job.progress = 0
        self.refresh_card(job_id)
        asyncio.create_task(self.discover_source(job_id, job.source_url))

    async def start_download(self, job_id: str, mode: str) -> None:
        job = self.jobs.get(job_id)
        if not job or not job.discovered or job.downloading:
            return

        card = self.query_one(f"#video-card-{job_id}", VideoCard)
        start_input = card.query_one(f"#trim-start-{job_id}", Input).value.strip() or None
        end_input = card.query_one(f"#trim-end-{job_id}", Input).value.strip() or None

        job.trim_start = start_input
        job.trim_end = end_input

        job.downloading = True
        job.download_failed = False
        job.last_download_mode = mode
        job.progress = 0
        job.status = "Preparing download..."
        self.refresh_card(job_id)
        asyncio.create_task(self.download_job(job_id, mode, start_input, end_input))

    async def discover_source(self, job_id: str, url: str) -> None:
        downloader = YouTubeDownloader()
        loop = asyncio.get_running_loop()
        results = await loop.run_in_executor(None, downloader.discover, url)

        if not results:
            failed_job = self.jobs.get(job_id)
            if failed_job:
                failed_job.discover_failed = True
                failed_job.discovered = False
                failed_job.status = "Discovery failed. Retry available."
                self.refresh_card(job_id)
            self.update_summary("Some discovery jobs failed.")
            return

        primary = results[0]
        primary_job = self.jobs.get(job_id)
        if primary_job:
            self.apply_discovery_result(primary_job, primary)
            self.refresh_card(primary_job.job_id)

        for entry in results[1:]:
            extra_job = self.create_job(source_url=url, target_url=entry["target_url"])
            self.apply_discovery_result(extra_job, entry)
            await self.mount_card(extra_job)

        discovered_count = sum(1 for job in self.jobs.values() if job.discovered)
        members_only_count = sum(1 for job in self.jobs.values() if job.is_members_only)
        failed_count = sum(1 for job in self.jobs.values() if job.discover_failed and not job.is_members_only)

        summary_parts = []
        if discovered_count > 0:
            summary_parts.append(f"{discovered_count} ready")
        if members_only_count > 0:
            summary_parts.append(f"{members_only_count} members-only")
        if failed_count > 0:
            summary_parts.append(f"{failed_count} failed")

        if not summary_parts:
            self.update_summary("Discovery complete.")
        else:
            self.update_summary(f"Discovery complete: {', '.join(summary_parts)}.")

        if self.all_discovery_tasks_finished():
            self.query_one("#analyze-btn", Button).disabled = False

    async def download_job(self, job_id: str, mode: str, start_time: str | None = None, end_time: str | None = None) -> None:
        job = self.jobs.get(job_id)
        if not job:
            return

        def progress_callback(payload: dict) -> None:
            self.call_from_thread(self.handle_download_progress, job_id, payload)

        downloader = YouTubeDownloader(progress_callback=progress_callback)
        loop = asyncio.get_running_loop()
        success, message = await loop.run_in_executor(
            None,
            downloader.download,
            job.target_url,
            mode,
            YouTubeDownloader.default_download_path(),
            start_time,
            end_time,
        )

        updated_job = self.jobs.get(job_id)
        if not updated_job:
            return

        updated_job.downloading = False
        if success:
            updated_job.download_failed = False
            updated_job.progress = 100
            updated_job.status = "Download complete."
            self.notify(f"Downloaded: {updated_job.title}", severity="information")
        else:
            updated_job.download_failed = True
            updated_job.status = f"Download failed: {message}"
            self.notify(f"Failed: {updated_job.title}", severity="error")

        self.refresh_card(job_id)

    def handle_download_progress(self, job_id: str, payload: dict) -> None:
        job = self.jobs.get(job_id)
        if not job:
            return

        status = payload.get("status")
        if status == "downloading":
            downloaded = payload.get("downloaded_bytes", 0)
            total = payload.get("total_bytes") or payload.get("total_bytes_estimate") or 0
            if total > 0:
                job.progress = max(0.0, min((downloaded / total) * 100, 100.0))
            speed = payload.get("_speed_str", "N/A")
            eta = payload.get("_eta_str", "N/A")

            info = payload.get("info_dict", {})
            vcodec = info.get("vcodec", "none")
            acodec = info.get("acodec", "none")
            comp = ""
            if vcodec != "none" and acodec == "none":
                comp = "video "
            elif vcodec == "none" and acodec != "none":
                comp = "audio "

            job.status = f"Downloading {comp}at {speed} | ETA {eta}"
        elif status == "processing":
            action = payload.get("action", "Processing")
            if action == "merging":
                job.progress = 100
                job.status = "Merging video and audio..."
            elif action == "finished":
                job.progress = 100
                job.status = "Finalizing files..."

        self.refresh_card(job_id)

    def apply_discovery_result(self, job: VideoJobState, entry: dict) -> None:
        job.platform = entry.get("platform", job.platform)
        if entry.get("error"):
            error_msg = entry["error"]
            if "members-only" in error_msg.lower():
                job.title = "Members-only Video"
                job.status = error_msg
                job.is_members_only = True
            else:
                job.title = entry.get("title", "Discovery failed")
                job.status = f"Discovery failed: {error_msg}"
                job.is_members_only = False
            job.author = entry.get("author", "Unknown")
            job.duration = entry.get("duration", "N/A")
            job.target_url = entry.get("target_url", job.source_url)
            job.discovered = False
            job.discover_failed = True
            job.progress = 0
            return

        job.target_url = entry["target_url"]
        job.title = entry.get("title", "Unknown title")
        job.author = entry.get("author", "Unknown")
        job.duration = entry.get("duration", "N/A")
        job.discovered = True
        job.discover_failed = False
        job.download_failed = False
        job.progress = 0
        job.status = "Ready for download."

    def create_job(self, source_url: str, target_url: str, status: str = "Queued") -> VideoJobState:
        self.job_counter += 1
        job_id = str(self.job_counter)
        detected_platform = YouTubeDownloader._detect_platform({}, target_url or source_url)
        job = VideoJobState(
            job_id=job_id,
            source_url=source_url,
            target_url=target_url,
            platform=detected_platform,
            status=status,
        )
        self.jobs[job_id] = job
        return job

    async def mount_card(self, job: VideoJobState) -> None:
        for empty_state in list(self.query("#empty-state")):
            await empty_state.remove()

        results_list = self.query_one("#results-list", Vertical)
        await results_list.mount(VideoCard(job))

    async def reset_results(self) -> None:
        self.jobs.clear()
        self.job_counter = 0
        results_list = self.query_one("#results-list", Vertical)
        for child in list(results_list.children):
            await child.remove()
        await results_list.mount(Static("No discovery jobs yet.", id="empty-state"))

    def refresh_card(self, job_id: str) -> None:
        job = self.jobs.get(job_id)
        if not job:
            return
        card = self.query_one(f"#video-card-{job_id}", VideoCard)
        card.apply_state(job)

    def update_summary(self, text: str) -> None:
        self.query_one("#results-summary", Static).update(text)

    def all_discovery_tasks_finished(self) -> bool:
        return all(job.discovered or job.discover_failed for job in self.jobs.values())

    def parse_urls(self, raw_value: str) -> list[str]:
        seen: set[str] = set()
        urls: list[str] = []
        for token in re.split(r"[\s,]+", raw_value.strip()):
            cleaned = token.strip()
            if not cleaned or cleaned in seen:
                continue
            seen.add(cleaned)
            urls.append(cleaned)
        return urls

    def _auth_status_text(self) -> str:
        state = self.auth_state
        marker = "[bold green]ONLINE[/bold green]" if state["enabled"] else "[bold red]OFFLINE[/bold red]"
        return (
            f"AUTH {marker}\n"
            f"[bold]{state['label']}[/bold]\n"
            f"{state['detail']}"
        )

    def refresh_auth_status(self) -> None:
        self.auth_state = YouTubeDownloader.auth_status()
        self.query_one("#auth-status", Static).update(self._auth_status_text())

    def _default_browser_spec(self) -> str:
        return (
            os.environ.get("YTDLP_BROWSER_SPEC", "").strip()
            or os.environ.get("YTDLP_COOKIES_FROM_BROWSER", "").strip()
        )


if __name__ == "__main__":
    app = YouTubeTUI()
    app.run()
