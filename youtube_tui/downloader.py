from __future__ import annotations

import os
import shutil
from typing import Any

import yt_dlp


class YouTubeDownloader:
    def __init__(self, progress_callback=None):
        self.progress_callback = progress_callback

    def progress_hook(self, payload: dict[str, Any]) -> None:
        if self.progress_callback:
            self.progress_callback(payload)

    def postprocessor_hook(self, payload: dict[str, Any]) -> None:
        if not self.progress_callback:
            return
        if payload["status"] == "started":
            self.progress_callback({"status": "processing", "action": "merging"})
        elif payload["status"] == "finished":
            self.progress_callback({"status": "processing", "action": "finished"})

    def discover(self, raw_url: str) -> list[dict[str, Any]]:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "extract_flat": "in_playlist",
            "skip_download": True,
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(raw_url, download=False)
        except Exception as exc:
            return [self._build_error_result(raw_url, str(exc))]

        if not info:
            return [self._build_error_result(raw_url, "No metadata returned.")]

        if info.get("entries"):
            results: list[dict[str, Any]] = []
            for entry in info["entries"]:
                if not entry:
                    continue
                results.append(self._build_result(entry, raw_url))
            if results:
                return results

        return [self._build_result(info, raw_url)]

    def download(self, url: str, quality: str = "best", output_path: str = "downloads") -> tuple[bool, str]:
        os.makedirs(output_path, exist_ok=True)
        ffmpeg_path = shutil.which("ffmpeg")

        ydl_opts = {
            "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "outtmpl": os.path.join(output_path, "%(title)s.%(ext)s"),
            "progress_hooks": [self.progress_hook],
            "postprocessor_hooks": [self.postprocessor_hook],
            "merge_output_format": "mp4",
            "quiet": True,
            "no_warnings": True,
            "nocheckcertificate": True,
            "ignoreerrors": False,
            "no_color": True,
            "prefer_ffmpeg": True,
        }

        if ffmpeg_path:
            ydl_opts["ffmpeg_location"] = ffmpeg_path

        if quality == "audio":
            ydl_opts["format"] = "bestaudio/best"
            ydl_opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ]

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                ydl.download([url])
                return True, "Success"
            except Exception as exc:
                return False, str(exc)

    def _build_result(self, info: dict[str, Any], fallback_url: str) -> dict[str, Any]:
        target_url = (
            info.get("webpage_url")
            or info.get("url")
            or fallback_url
        )
        author = info.get("uploader") or info.get("channel") or "Unknown"
        duration = info.get("duration_string")
        if not duration and info.get("duration"):
            duration = self._format_duration(info["duration"])

        return {
            "source_url": fallback_url,
            "target_url": target_url,
            "title": info.get("title", "Unknown"),
            "author": author,
            "duration": duration or "N/A",
        }

    def _build_error_result(self, raw_url: str, error: str) -> dict[str, Any]:
        return {
            "source_url": raw_url,
            "target_url": raw_url,
            "title": "Discovery failed",
            "author": "Unknown",
            "duration": "N/A",
            "error": error,
        }

    def _format_duration(self, seconds: int) -> str:
        minutes, secs = divmod(int(seconds), 60)
        hours, minutes = divmod(minutes, 60)
        if hours:
            return f"{hours}:{minutes:02d}:{secs:02d}"
        return f"{minutes}:{secs:02d}"
