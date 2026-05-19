import yt_dlp
import os

class YouTubeDownloader:
    def __init__(self, progress_callback=None):
        self.progress_callback = progress_callback

    def progress_hook(self, d):
        if self.progress_callback:
            self.progress_callback(d)

    def postprocessor_hook(self, d):
        if d['status'] == 'started':
            if self.progress_callback:
                self.progress_callback({'status': 'processing', 'action': 'merging'})
        elif d['status'] == 'finished':
             if self.progress_callback:
                self.progress_callback({'status': 'processing', 'action': 'finished'})

    def get_metadata(self, url):
        ydl_opts = {
            'quiet': True, 
            'no_warnings': True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                info = ydl.extract_info(url, download=False)
                if not info: return None
                return {
                    'title': info.get('title', 'Unknown'),
                    'author': info.get('uploader', info.get('channel', 'Unknown')),
                    'duration': info.get('duration_string', 'N/A'),
                    'views': info.get('view_count', 0),
                    'thumbnail': info.get('thumbnail', ''),
                }
            except Exception as e:
                return {'error': str(e)}

    def download(self, url, quality='best', output_path='downloads'):
        os.makedirs(output_path, exist_ok=True)
        
        import shutil
        ffmpeg_path = shutil.which('ffmpeg')

        ydl_opts = {
            'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
            'outtmpl': os.path.join(output_path, '%(title)s.%(ext)s'),
            'progress_hooks': [self.progress_hook],
            'postprocessor_hooks': [self.postprocessor_hook],
            'merge_output_format': 'mp4',
            'quiet': True,
            'no_warnings': True,
            'nocheckcertificate': True,
            'ignoreerrors': False,
            'no_color': True,
            'prefer_ffmpeg': True,
        }
        
        if ffmpeg_path:
            ydl_opts['ffmpeg_location'] = ffmpeg_path

        if quality == 'audio':
            ydl_opts['format'] = 'bestaudio/best'
            ydl_opts['postprocessors'] = [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }]

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                ydl.download([url])
                return True, "Success"
            except Exception as e:
                return False, str(e)
