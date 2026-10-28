from __future__ import annotations

import contextlib
import datetime as dt
import io
import os
import shutil
from typing import Any

import yt_dlp

def get_device_download_dir() -> str:
    """Resolve the native user Downloads folder on the device (macOS, Linux, Windows).

    Priority:
    1. VOID_DOWNLOAD_DIR or DOWNLOAD_DIR environment variable
    2. Linux XDG download directory via xdg-user-dir
    3. User's ~/Downloads directory
    4. Fallback to local 'downloads' directory if ~/Downloads cannot be created
    """
    # 1. Environment variable override
    custom_dir = os.environ.get("VOID_DOWNLOAD_DIR") or os.environ.get("DOWNLOAD_DIR")
    if custom_dir:
        expanded = os.path.expanduser(custom_dir)
        try:
            os.makedirs(expanded, exist_ok=True)
            return expanded
        except OSError:
            pass

    # 2. XDG standard Downloads folder on Linux
    if shutil.which("xdg-user-dir"):
        try:
            import subprocess

            out = subprocess.check_output(
                ["xdg-user-dir", "DOWNLOAD"], text=True, stderr=subprocess.DEVNULL
            ).strip()
            if out:
                os.makedirs(out, exist_ok=True)
                return out
        except Exception:
            pass

    # 3. Native device Downloads folder (~/Downloads) on macOS, Linux, Windows
    user_downloads = os.path.expanduser("~/Downloads")
    try:
        os.makedirs(user_downloads, exist_ok=True)
        return user_downloads
    except OSError:
        pass

    # 4. Fallback to local directory
    fallback = os.path.join(os.path.dirname(os.path.abspath(__file__)), "downloads")
    os.makedirs(fallback, exist_ok=True)
    return fallback


DEFAULT_COOKIE_EXPORT_PATH = os.path.expanduser("~/.cache/void-archive/youtube.cookies.txt")
DEFAULT_DOWNLOAD_DIR = get_device_download_dir()
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
    # YouTube / Google
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
    # Facebook
    "c_user",
    "xs",
    # Instagram
    "sessionid",
    "ds_user_id",
    # Twitter / X
    "auth_token",
    "ct0",
    # TikTok
    "sessionid",
    "sid_guard",
    "sessionid_ss",
    # Reddit
    "reddit_session",
    # Twitch
    "auth-token",
    # Dailymotion
    "ts",
    "sid",
    # Vimeo
    "vimeo",
    # SoundCloud
    "oauth_token",
    # Bilibili
    "SESSDATA",
    "bili_jct",
}


class QuietLogger:
    """Redirect yt-dlp internal logging so it does not interfere with Textual TUI."""

    def debug(self, msg: str) -> None:
        pass

    def info(self, msg: str) -> None:
        pass

    def warning(self, msg: str) -> None:
        pass

    def error(self, msg: str) -> None:
        pass


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

    @staticmethod
    def _detect_platform(info: dict[str, Any], url: str) -> str:
        key = info.get("extractor_key") or info.get("extractor") or ""
        if key and key.lower() not in {"generic", "url"}:
            return key.capitalize()

        from urllib.parse import urlparse

        domain = urlparse(url).netloc.lower()
        for prefix in ("www.", "m.", "mobile."):
            if domain.startswith(prefix):
                domain = domain[len(prefix) :]
        parts = domain.split(".")
        return parts[0].capitalize() if parts and parts[0] else "Media"

    @staticmethod
    def _is_single_video_target(url: str) -> bool:
        lowered = url.lower()
        if any(token in lowered for token in ["/playlist", "/channel/", "/user/", "/c/@", "list="]) and not (
            "/watch" in lowered or "youtu.be/" in lowered or "/shorts/" in lowered
        ):
            return False
        if any(
            token in lowered
            for token in [
                "dailymotion.com/playlist",
                "vimeo.com/channels",
                "vimeo.com/album",
                "tiktok.com/@",
                "tiktok.com/tag/",
            ]
        ) and not ("/video/" in lowered or "/reel/" in lowered or "/shorts/" in lowered):
            return False
        return True

    def discover(self, raw_url: str) -> list[dict[str, Any]]:
        is_single = self._is_single_video_target(raw_url)
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "skip_download": True,
            "windowsfilenames": True,
            "noplaylist": is_single,
            "extract_flat": "in_playlist",
            "logger": QuietLogger(),
        }
        ydl_opts.update(self._auth_options())

        info = None
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(raw_url, download=False, process=True)
        except Exception as exc:
            # If discovery failed with stale/invalid cookies, retry once without auth for public videos
            if "cookiefile" in ydl_opts or "cookiesfrombrowser" in ydl_opts:
                retry_opts = dict(ydl_opts)
                retry_opts.pop("cookiefile", None)
                retry_opts.pop("cookiesfrombrowser", None)
                try:
                    with yt_dlp.YoutubeDL(retry_opts) as retry_ydl:
                        info = retry_ydl.extract_info(raw_url, download=False, process=True)
                except Exception:
                    return [self._build_error_result(raw_url, self._humanize_error(str(exc)))]
            else:
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

    def download(
        self,
        url: str,
        quality: str = "video:best",
        output_path: str | None = None,
        start_time: str | None = None,
        end_time: str | None = None,
    ) -> tuple[bool, str]:
        target_dir = output_path or self.default_download_path()
        os.makedirs(target_dir, exist_ok=True)
        ffmpeg_path = shutil.which("ffmpeg")

        start_secs = self._parse_time_to_seconds(start_time)
        end_secs = self._parse_time_to_seconds(end_time)

        if start_time and start_time.strip() and start_secs is None:
            return False, "Invalid start time format. Use HH:MM:SS, MM:SS, or seconds."
        if end_time and end_time.strip() and end_secs is None:
            return False, "Invalid end time format. Use HH:MM:SS, MM:SS, or seconds."

        if start_secs is not None and end_secs is not None and end_secs <= start_secs:
            return False, "End time must be greater than start time for trimming."

        trim_suffix = ""
        if start_secs is not None or end_secs is not None:
            clean_start = (start_time or "0").strip().replace(":", "-")
            clean_end = (end_time or "end").strip().replace(":", "-")
            trim_suffix = f" [Trim {clean_start} to {clean_end}]"

        ydl_opts = {
            "format": "bestvideo*+bestaudio/best",
            "paths": {"home": target_dir},
            "outtmpl": f"%(title,id).100B{trim_suffix}.%(ext)s",
            "progress_hooks": [self.progress_hook],
            "postprocessor_hooks": [self.postprocessor_hook],
            "merge_output_format": "mp4",
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "nocheckcertificate": True,
            "ignoreerrors": False,
            "no_color": True,
            "prefer_ffmpeg": True,
            "windowsfilenames": True,
            "noplaylist": True,
            "logger": QuietLogger(),
        }
        ydl_opts.update(self._auth_options())

        if start_secs is not None or end_secs is not None:
            from yt_dlp.utils import download_range_func

            actual_start = start_secs if start_secs is not None else 0.0
            actual_end = end_secs if end_secs is not None else float("inf")
            ydl_opts["download_ranges"] = download_range_func(None, [(actual_start, actual_end)])
            ydl_opts["force_keyframes_at_cuts"] = True

        if ffmpeg_path:
            ydl_opts["ffmpeg_location"] = ffmpeg_path

        download_type, resolution = self._parse_download_mode(quality)

        if download_type == "audio":
            ydl_opts["format"] = "bestaudio/best"
            ydl_opts.pop("merge_output_format", None)
            ydl_opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ]
        else:
            ydl_opts["format"] = self._video_format_for_resolution(resolution)

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
                return True, "Success"
        except Exception as exc:
            # Fallback retry without auth if cookies were rejected or invalid
            if "cookiefile" in ydl_opts or "cookiesfrombrowser" in ydl_opts:
                retry_opts = dict(ydl_opts)
                retry_opts.pop("cookiefile", None)
                retry_opts.pop("cookiesfrombrowser", None)
                try:
                    with yt_dlp.YoutubeDL(retry_opts) as retry_ydl:
                        retry_ydl.download([url])
                        return True, "Success (downloaded using public access; cached cookies were rejected)"
                except Exception:
                    pass
            return False, self._humanize_error(str(exc))

    def _build_result(self, info: dict[str, Any], fallback_url: str) -> dict[str, Any]:
        target_url = info.get("webpage_url") or info.get("url") or fallback_url
        author = info.get("uploader") or info.get("channel") or info.get("creator") or info.get("uploader_id") or "Unknown"
        duration = info.get("duration_string")
        if not duration and info.get("duration"):
            duration = self._format_duration(info["duration"])

        platform = self._detect_platform(info, fallback_url)

        return {
            "source_url": fallback_url,
            "target_url": target_url,
            "title": info.get("title", "Unknown"),
            "author": author,
            "duration": duration or "N/A",
            "platform": platform,
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

    def _parse_time_to_seconds(self, time_str: str | None) -> float | None:
        if not time_str:
            return None
        time_str = time_str.strip()
        if not time_str:
            return None
        try:
            return float(time_str)
        except ValueError:
            pass
        parts = time_str.split(":")
        try:
            if len(parts) == 2:
                return int(parts[0]) * 60 + float(parts[1])
            elif len(parts) == 3:
                return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
        except ValueError:
            pass
        return None

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
        platform = self._detect_platform({}, raw_url)
        return {
            "source_url": raw_url,
            "target_url": raw_url,
            "title": "Discovery failed",
            "author": "Unknown",
            "duration": "N/A",
            "platform": platform,
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
        if "file name too long" in lowered or "errno 63" in lowered or "errno 36" in lowered:
            return "File name too long for the filesystem. The output filename template has been truncated."
        if "members-only content" in lowered or "join this channel" in lowered:
            return "This video is members-only. To download it, please export signed-in cookies using the AUTH panel."
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
        if "http error 403" in lowered or "403: forbidden" in lowered or "access denied" in lowered:
            return (
                "YouTube returned 403 Forbidden. This typically happens with outdated extractors or expired account cookies. "
                "Try updating dependencies with ./run.sh --update or refreshing your cookie session."
            )
        if "ffmpeg exited with code" in lowered:
            return f"FFmpeg processing failed ({error}). Ensure ffmpeg is installed and trimming range is valid."
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
    def default_download_path(cls) -> str:
        override = os.environ.get("VOID_DOWNLOAD_DIR") or os.environ.get("DOWNLOAD_DIR")
        if override:
            p = os.path.expanduser(override)
            os.makedirs(p, exist_ok=True)
            return p
        return DEFAULT_DOWNLOAD_DIR

    @classmethod
    def friendly_download_path(cls) -> str:
        path = cls.default_download_path()
        home = os.path.expanduser("~")
        if path == home:
            return "~"
        if path.startswith(home + os.sep):
            return "~" + path[len(home):]
        return path

    @classmethod
    def _detect_cookie_platform(cls, domain: str) -> str | None:
        domain = domain.lower()
        if "youtube.com" in domain or "google.com" in domain:
            return "YouTube"
        elif "facebook.com" in domain:
            return "Facebook"
        elif "instagram.com" in domain:
            return "Instagram"
        elif "twitter.com" in domain or "x.com" in domain:
            return "Twitter/X"
        elif "tiktok.com" in domain:
            return "TikTok"
        elif "reddit.com" in domain:
            return "Reddit"
        elif "dailymotion.com" in domain:
            return "Dailymotion"
        elif "twitch.tv" in domain:
            return "Twitch"
        elif "vimeo.com" in domain:
            return "Vimeo"
        elif "soundcloud.com" in domain:
            return "SoundCloud"
        elif "bilibili.com" in domain:
            return "Bilibili"
        return None

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
                    "The export completed, but no supported platform sign-in cookies were found."
                ),
                "needs_refresh": True,
                "refresh_reason": "unauthenticated",
            }

        platforms = sorted(session_state.get("platforms") or [])
        platforms_text = f"Signed-in: {', '.join(platforms)}" if platforms else "Session active"

        if session_state.get("is_expired"):
            expiry = session_state.get("expiry")
            expires_local = "unknown"
            if expiry:
                expires_at = dt.datetime.fromtimestamp(expiry, tz=dt.timezone.utc)
                expires_local = expires_at.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
            return {
                "enabled": False,
                "label": "Cookies expired",
                "detail": f"{prefix}: {cookie_file}\nExpired sign-in: {platforms_text} (expired: {expires_local})",
                "needs_refresh": True,
                "refresh_reason": "expired",
            }

        expiry = session_state.get("expiry")
        if expiry is None:
            return {
                "enabled": True,
                "label": "Cookies enabled",
                "detail": f"{prefix}: {cookie_file}\n{platforms_text}. Expiry: session / unknown",
                "needs_refresh": False,
                "refresh_reason": "",
            }

        now = dt.datetime.now(dt.timezone.utc)
        expires_at = dt.datetime.fromtimestamp(expiry, tz=dt.timezone.utc)
        expires_local = expires_at.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

        hours_left = (expires_at - now).total_seconds() / 3600
        if hours_left <= 24:
            return {
                "enabled": True,
                "label": "Cookies expiring soon",
                "detail": f"{prefix}: {cookie_file}\n{platforms_text} (expires: {expires_local})",
                "needs_refresh": True,
                "refresh_reason": "expiring_soon",
            }

        return {
            "enabled": True,
            "label": "Cookies enabled",
            "detail": f"{prefix}: {cookie_file}\n{platforms_text} (expires: {expires_local})",
            "needs_refresh": False,
            "refresh_reason": "",
        }

    @classmethod
    def _cookie_session_state(cls, cookie_file: str) -> dict[str, Any]:
        now = dt.datetime.now(dt.timezone.utc).timestamp()
        active_platforms: set[str] = set()
        expired_platforms: set[str] = set()
        active_expiries: list[int] = []
        expired_expiries: list[int] = []

        with open(cookie_file, encoding="utf-8", errors="ignore") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 7:
                    continue
                domain = parts[0].lower()
                name = parts[5].strip()
                if name not in AUTH_COOKIE_NAMES:
                    continue

                platform = cls._detect_cookie_platform(domain)
                if not platform:
                    continue

                expiry_raw = parts[4].strip()
                norm_expiry = 0
                if expiry_raw.isdigit():
                    norm_expiry = cls._normalize_cookie_expiry(int(expiry_raw))

                if norm_expiry == 0 or norm_expiry > now:
                    active_platforms.add(platform)
                    if norm_expiry > 0:
                        active_expiries.append(norm_expiry)
                else:
                    expired_platforms.add(platform)
                    if norm_expiry > 0:
                        expired_expiries.append(norm_expiry)

        truly_expired = expired_platforms - active_platforms
        has_active = len(active_platforms) > 0
        has_any_auth = (len(active_platforms) + len(expired_platforms)) > 0

        if active_expiries:
            target_expiry = min(active_expiries)
        elif expired_expiries:
            target_expiry = max(expired_expiries)
        else:
            target_expiry = None

        return {
            "has_auth_cookies": has_any_auth,
            "has_active_session": has_active,
            "expiry": target_expiry,
            "platforms": active_platforms if has_active else truly_expired,
            "is_expired": not has_active and len(truly_expired) > 0,
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
            status = self._cookie_file_status(managed_cookie_file, managed=True)
            if status.get("enabled"):
                return managed_cookie_file

        return None

    def export_cookies(self, browser_spec: str, output_path: str | None = None) -> tuple[bool, str, str]:
        target_path = output_path or self.default_cookie_export_path()
        os.makedirs(os.path.dirname(target_path), exist_ok=True)

        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "skip_download": True,
            "cookiefile": target_path,
            "cookiesfrombrowser": self._parse_browser_spec(browser_spec),
        }

        try:
            null_io = io.StringIO()
            with contextlib.redirect_stdout(null_io), contextlib.redirect_stderr(null_io):
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    ydl.save_cookies()
            session_state = self._cookie_session_state(target_path)
            if not session_state["has_auth_cookies"]:
                return False, "Export completed, but no supported platform sign-in cookies were found.", target_path
            platforms = sorted(session_state.get("platforms") or [])
            details = f" ({', '.join(platforms)})" if platforms else ""
            return True, f"Cookies exported to {target_path}{details}", target_path
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


# Backward-compatible alias
VideoDownloader = YouTubeDownloader
