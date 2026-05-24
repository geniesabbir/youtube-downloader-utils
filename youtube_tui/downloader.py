from __future__ import annotations

import datetime as dt
import os
import shutil
from typing import Any

import yt_dlp

DEFAULT_COOKIE_EXPORT_PATH = os.path.expanduser("~/.cache/void-archive/youtube.cookies.txt")
AUTO_BROWSER_SPECS = (
    "brave",
    "chrome",
    "chromium",
    "edge",
    "vivaldi",
    "opera",
    "firefox",
    "safari",
)
AUTH_COOKIE_NAMES = {
    "SID",
    "HSID",
    "SSID",
    "APISID",
    "SAPISID",
    "__Secure-1PSID",
    "__Secure-3PSID",
    "__Secure-1PAPISID",
    "__Secure-3PAPISID",
    "LOGIN_INFO",
}


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
            "skip_download": True,
            "noplaylist": False,
        }
        ydl_opts.update(self._auth_options())

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(raw_url, download=False, process=False)
        except Exception as exc:
            return [self._build_error_result(raw_url, self._humanize_error(str(exc)))]

        if not info:
            return [self._build_error_result(raw_url, "No metadata returned.")]

        if info.get("entries"):
            results: list[dict[str, Any]] = []
            for entry in info["entries"]:
                if not entry:
                    continue
                results.append(self._build_result(self._normalize_entry(entry), raw_url))
            if results:
                return results

        return [self._build_result(self._normalize_entry(info), raw_url)]

    def download(self, url: str, quality: str = "video:best", output_path: str = "downloads") -> tuple[bool, str]:
        os.makedirs(output_path, exist_ok=True)
        ffmpeg_path = shutil.which("ffmpeg")

        ydl_opts = {
            "format": "bestvideo*+bestaudio/best",
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
        ydl_opts.update(self._auth_options())

        if ffmpeg_path:
            ydl_opts["ffmpeg_location"] = ffmpeg_path

        download_type, resolution = self._parse_download_mode(quality)

        if download_type == "audio":
            ydl_opts["format"] = "bestaudio/best"
            ydl_opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ]
        else:
            ydl_opts["format"] = self._video_format_for_resolution(resolution)

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                ydl.download([url])
                return True, "Success"
            except Exception as exc:
                return False, self._humanize_error(str(exc))

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

    def _normalize_entry(self, info: dict[str, Any]) -> dict[str, Any]:
        if info.get("_type") == "url" and info.get("ie_key"):
            return info
        return info

    def _parse_download_mode(self, mode: str) -> tuple[str, str]:
        download_type, _, resolution = (mode or "video:best").partition(":")
        if download_type not in {"video", "audio"}:
            download_type = "video"
        resolution = resolution or "best"
        return download_type, resolution

    def _video_format_for_resolution(self, resolution: str) -> str:
        if resolution == "best":
            return "bestvideo*+bestaudio/best"
        if resolution.isdigit():
            return (
                f"bestvideo*[height<={resolution}]+bestaudio/"
                f"best[height<={resolution}]/best"
            )
        return "bestvideo*+bestaudio/best"

    def _build_error_result(self, raw_url: str, error: str) -> dict[str, Any]:
        return {
            "source_url": raw_url,
            "target_url": raw_url,
            "title": "Discovery failed",
            "author": "Unknown",
            "duration": "N/A",
            "error": error,
        }

    def _auth_options(self) -> dict[str, Any]:
        """Load optional yt-dlp auth settings from the environment."""
        options: dict[str, Any] = {}

        cookie_file = self._resolve_cookie_file()
        if cookie_file:
            options["cookiefile"] = cookie_file
            return options

        browser_spec = os.environ.get("YTDLP_BROWSER_SPEC", "").strip()
        if browser_spec:
            options["cookiesfrombrowser"] = self._parse_browser_spec(browser_spec)
            return options

        browser_name = os.environ.get("YTDLP_COOKIES_FROM_BROWSER", "").strip()
        if browser_name:
            options["cookiesfrombrowser"] = self._parse_browser_spec(browser_name)

        return options

    def _humanize_error(self, error: str) -> str:
        lowered = error.lower()
        if "sign in to confirm you're not a bot" in lowered:
            return (
                "YouTube rejected the request and now requires authenticated cookies. "
                "Set YTDLP_BROWSER_SPEC to a yt-dlp browser spec, or "
                "YTDLP_COOKIES_FILE=/absolute/path/to/cookies.txt, then retry."
            )
        if "unsupported browser specified for cookies" in lowered:
            return (
                "yt-dlp does not support that browser name for cookie extraction. "
                "Use a supported browser spec or export a cookies.txt file instead."
            )
        if "cannot decrypt v10 cookies" in lowered or "could not be decrypted" in lowered:
            return (
                "yt-dlp could not decrypt this browser's cookies on this machine. "
                "Export a Netscape-format cookies.txt file from the browser and use that instead."
            )
        return error

    def _parse_browser_spec(self, spec: str) -> tuple[str, ...]:
        """
        Convert a yt-dlp browser spec into the tuple format expected by yt-dlp.

        Supported examples:
        - brave
        - chrome:Profile 1
        - chromium:/full/profile/path
        - safari:default
        - firefox:default:container-name
        """
        parts = [part.strip() for part in spec.split(":")]
        while parts and not parts[-1]:
            parts.pop()
        return tuple(part for part in parts if part)

    @classmethod
    def auth_status(cls) -> dict[str, str | bool]:
        browser_spec = os.environ.get("YTDLP_BROWSER_SPEC", "").strip()
        browser_name = os.environ.get("YTDLP_COOKIES_FROM_BROWSER", "").strip()
        cookie_file = os.environ.get("YTDLP_COOKIES_FILE", "").strip()
        managed_cookie_file = cls.default_cookie_export_path()

        if cookie_file:
            return cls._cookie_file_status(cookie_file)

        if os.path.exists(managed_cookie_file):
            return cls._cookie_file_status(managed_cookie_file, managed=True)

        if browser_spec:
            return {
                "enabled": True,
                "label": "Cookies enabled",
                "detail": f"Live browser access: {browser_spec}",
                "needs_refresh": False,
            }
        if browser_name:
            return {
                "enabled": True,
                "label": "Cookies enabled",
                "detail": f"Live browser access: {browser_name}",
                "needs_refresh": False,
            }
        return {
            "enabled": False,
            "label": "Cookies disabled",
            "detail": "No YTDLP_BROWSER_SPEC, YTDLP_COOKIES_FROM_BROWSER, or YTDLP_COOKIES_FILE set.",
            "needs_refresh": False,
        }

    @classmethod
    def default_cookie_export_path(cls) -> str:
        return DEFAULT_COOKIE_EXPORT_PATH

    @classmethod
    def _cookie_file_status(cls, cookie_file: str, managed: bool = False) -> dict[str, str | bool]:
        if not os.path.exists(cookie_file):
            return {
                "enabled": False,
                "label": "Cookies misconfigured",
                "detail": f"Cookie file (missing): {cookie_file}",
                "needs_refresh": True,
                "refresh_reason": "missing",
            }

        session_state = cls._cookie_session_state(cookie_file)
        prefix = "Using exported cookie cache" if managed else "Cookie file"
        if not session_state["has_auth_cookies"]:
            return {
                "enabled": False,
                "label": "Sign-in not detected",
                "detail": (
                    f"{prefix}: {cookie_file}\n"
                    "The export completed, but no YouTube/Google sign-in cookies were found."
                ),
                "needs_refresh": True,
                "refresh_reason": "unauthenticated",
            }

        expiry = session_state["expiry"]
        if expiry is None:
            return {
                "enabled": True,
                "label": "Cookies enabled",
                "detail": f"{prefix}: {cookie_file}\nSigned-in session detected. Expiry: unknown",
                "needs_refresh": False,
                "refresh_reason": "",
            }

        now = dt.datetime.now(dt.timezone.utc)
        expires_at = dt.datetime.fromtimestamp(expiry, tz=dt.timezone.utc)
        expires_local = expires_at.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

        if expires_at <= now:
            return {
                "enabled": False,
                "label": "Cookies expired",
                "detail": f"{prefix}: {cookie_file}\nSigned-in session expired: {expires_local}",
                "needs_refresh": True,
                "refresh_reason": "expired",
            }

        hours_left = (expires_at - now).total_seconds() / 3600
        if hours_left <= 24:
            return {
                "enabled": True,
                "label": "Cookies expiring soon",
                "detail": f"{prefix}: {cookie_file}\nSigned-in session expires: {expires_local}",
                "needs_refresh": True,
                "refresh_reason": "expiring_soon",
            }

        return {
            "enabled": True,
            "label": "Cookies enabled",
            "detail": f"{prefix}: {cookie_file}\nSigned-in session expires: {expires_local}",
            "needs_refresh": False,
            "refresh_reason": "",
        }

    @classmethod
    def _cookie_session_state(cls, cookie_file: str) -> dict[str, bool | int | None]:
        expiries: list[int] = []
        has_auth_cookies = False

        with open(cookie_file, encoding="utf-8", errors="ignore") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 7:
                    continue
                domain = parts[0].lower()
                if "youtube.com" not in domain and "google.com" not in domain:
                    continue
                name = parts[5].strip()
                if name not in AUTH_COOKIE_NAMES:
                    continue
                has_auth_cookies = True
                expiry_raw = parts[4].strip()
                if not expiry_raw.isdigit():
                    continue
                expiry = cls._normalize_cookie_expiry(int(expiry_raw))
                if expiry > 0:
                    expiries.append(expiry)

        return {
            "has_auth_cookies": has_auth_cookies,
            "expiry": min(expiries) if expiries else None,
        }

    @classmethod
    def _normalize_cookie_expiry(cls, expiry: int) -> int:
        """
        Normalize cookie expiry values into Unix seconds.

        Netscape cookies normally use Unix seconds, but some exports may contain
        Chromium/WebKit microseconds since 1601-01-01.
        """
        if expiry <= 0:
            return expiry
        if expiry > 10_000_000_000:
            return max(0, int(expiry / 1_000_000) - 11_644_473_600)
        return expiry

    def _resolve_cookie_file(self) -> str | None:
        explicit_cookie_file = os.environ.get("YTDLP_COOKIES_FILE", "").strip()
        if explicit_cookie_file and os.path.exists(explicit_cookie_file):
            return explicit_cookie_file

        managed_cookie_file = self.default_cookie_export_path()
        if os.path.exists(managed_cookie_file):
            return managed_cookie_file

        return None

    def export_cookies(self, browser_spec: str, output_path: str | None = None) -> tuple[bool, str, str]:
        target_path = output_path or self.default_cookie_export_path()
        os.makedirs(os.path.dirname(target_path), exist_ok=True)

        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "cookiefile": target_path,
            "cookiesfrombrowser": self._parse_browser_spec(browser_spec),
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.save_cookies()
            session_state = self._cookie_session_state(target_path)
            if not session_state["has_auth_cookies"]:
                return False, "Export completed, but no signed-in YouTube/Google cookies were found.", target_path
            return True, f"Cookies exported to {target_path}", target_path
        except Exception as exc:
            return False, self._humanize_error(str(exc)), target_path

    @classmethod
    def auto_export_cookies(cls) -> tuple[bool, str, str | None, str | None]:
        """
        Try common browser specs and return the first signed-in cookie export.
        """
        downloader = cls()
        target_path = cls.default_cookie_export_path()
        errors: list[str] = []

        for browser_spec in AUTO_BROWSER_SPECS:
            success, message, cookie_path = downloader.export_cookies(browser_spec, target_path)
            if success:
                return True, message, browser_spec, cookie_path
            errors.append(f"{browser_spec}: {message}")

        return False, " | ".join(errors), None, None

    def _format_duration(self, seconds: int) -> str:
        minutes, secs = divmod(int(seconds), 60)
        hours, minutes = divmod(minutes, 60)
        if hours:
            return f"{hours}:{minutes:02d}:{secs:02d}"
        return f"{minutes}:{secs:02d}"
