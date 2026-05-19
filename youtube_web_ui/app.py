import os
import threading
import uuid
import subprocess
import platform
import time
from flask import Flask, request, jsonify, render_template, send_from_directory
import yt_dlp

app = Flask(__name__)

# Store progress and stop flags
downloads = {}
stop_tasks = {}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/info', methods=['POST'])
def get_info():
    data = request.json
    url = data.get('url')
    if not url:
        return jsonify({'error': 'URL is required'}), 400

    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': False,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            
            video_formats = []
            audio_formats = []
            seen_video = set()
            seen_audio = set()

            for f in info.get('formats', []):
                # Video formats
                if f.get('vcodec') != 'none' and f.get('height'):
                    res = f"{f['height']}p"
                    vcodec = f.get('vcodec', 'none')
                    acodec = f.get('acodec', 'none')
                    
                    key = f"{res}-{vcodec}-{acodec}"
                    if key not in seen_video:
                        seen_video.add(key)
                        video_formats.append({
                            'format_id': f['format_id'],
                            'resolution': res,
                            'ext': f.get('ext', 'mp4'),
                            'fps': f.get('fps', ''),
                            'needs_merge': (acodec == 'none'),
                            'vcodec': vcodec,
                            'acodec': acodec
                        })
                
                # Audio formats
                if f.get('vcodec') == 'none' and f.get('acodec') != 'none':
                    abr = f.get('abr', 0)
                    ext = f.get('ext', 'm4a')
                    key = f"{abr}-{ext}"
                    if key not in seen_audio:
                        seen_audio.add(key)
                        audio_formats.append({
                            'format_id': f['format_id'],
                            'ext': ext,
                            'abr': round(abr) if abr else 'unknown',
                            'note': f.get('format_note', '')
                        })
            
            # Sort video by height, audio by bitrate
            video_formats.sort(key=lambda x: int(x['resolution'].replace('p', '')), reverse=True)
            audio_formats.sort(key=lambda x: x['abr'] if isinstance(x['abr'], (int, float)) else 0, reverse=True)

            return jsonify({
                'title': info.get('title'),
                'thumbnail': info.get('thumbnail'),
                'video_formats': video_formats,
                'audio_formats': audio_formats
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def progress_hook(d, task_id):
    # Check if task should be stopped
    if stop_tasks.get(task_id):
        raise Exception("Download cancelled by user")

    if d['status'] == 'downloading':
        total = d.get('total_bytes') or d.get('total_bytes_estimate')
        downloaded = d.get('downloaded_bytes', 0)
        speed = d.get('speed', 0)
        eta = d.get('eta', 0)
        
        info = d.get('info_dict', {})
        vcodec = info.get('vcodec', 'none')
        acodec = info.get('acodec', 'none')
        
        component = "Video"
        if vcodec == 'none' and acodec != 'none':
            component = "Audio"
        elif vcodec != 'none' and acodec != 'none':
            component = "Media"
            
        if total:
            percent = (downloaded / total) * 100
        else:
            percent = 0
            
        downloads[task_id].update({
            'status': 'downloading',
            'percent': round(percent, 2),
            'speed': speed,
            'eta': eta,
            'message': f'Downloading {component}...'
        })
    elif d['status'] == 'finished':
        downloads[task_id].update({
            'status': 'processing',
            'percent': 100,
            'message': 'Download finished, preparing for next step...'
        })

def postprocessor_hook(d, task_id):
    if stop_tasks.get(task_id):
        raise Exception("Download cancelled by user")
        
    if d['status'] == 'started':
        pp_name = d.get('postprocessor', 'Post-processor')
        msg = f'Processing: {pp_name}...'
        if pp_name == 'Merger':
            msg = 'Merging video and audio layers...'
        
        downloads[task_id].update({
            'status': 'processing',
            'message': msg
        })
    elif d['status'] == 'finished':
        downloads[task_id].update({
            'status': 'processing',
            'message': 'Processing step complete.'
        })

def download_worker(url, format_id, task_id, mode):
    # Ensure downloads folder exists
    download_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'downloads')
    os.makedirs(download_dir, exist_ok=True)
    
    # Configure format based on mode
    if mode == 'both':
        format_str = f'{format_id}+bestaudio[ext=m4a]/best[ext=mp4]/best'
        merge_fmt = 'mp4'
    elif mode == 'video':
        format_str = format_id
        merge_fmt = None
    elif mode == 'audio':
        format_str = format_id
        merge_fmt = None
    else:
        format_str = 'best'
        merge_fmt = 'mp4'

    ydl_opts = {
        'format': format_str,
        'merge_output_format': merge_fmt,
        'outtmpl': os.path.join(download_dir, '%(title)s.%(ext)s'),
        'progress_hooks': [lambda d: progress_hook(d, task_id)],
        'postprocessor_hooks': [lambda d: postprocessor_hook(d, task_id)],
        'quiet': True,
        'no_warnings': True,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            # Extract info first to get the correct filename
            info = ydl.extract_info(url, download=False)
            ydl.download([url])
            
        if stop_tasks.get(task_id):
            downloads[task_id]['status'] = 'cancelled'
            downloads[task_id]['message'] = 'Download cancelled.'
        else:
            # Get the final filename
            final_file = ydl.prepare_filename(info)
            # If it's a merge, the extension might change to the merge_fmt
            if merge_fmt and not final_file.endswith('.' + merge_fmt):
                final_file = os.path.splitext(final_file)[0] + '.' + merge_fmt
            
            downloads[task_id]['status'] = 'completed'
            downloads[task_id]['message'] = 'Download complete! Ready to save.'
            downloads[task_id]['filename'] = os.path.basename(final_file)
    except Exception as e:
        if "cancelled" in str(e).lower():
            downloads[task_id]['status'] = 'cancelled'
            downloads[task_id]['message'] = 'Download cancelled.'
        else:
            downloads[task_id]['status'] = 'error'
            downloads[task_id]['message'] = str(e)
    finally:
        # Cleanup stop flag
        if task_id in stop_tasks:
            del stop_tasks[task_id]


@app.route('/api/download', methods=['POST'])
def start_download():
    data = request.json
    url = data.get('url')
    format_id = data.get('format_id')
    mode = data.get('mode', 'both')
    
    if not url or not format_id:
        return jsonify({'error': 'URL and format_id are required'}), 400
        
    task_id = str(uuid.uuid4())
    downloads[task_id] = {
        'status': 'starting',
        'percent': 0,
        'speed': 0,
        'eta': 0
    }
    stop_tasks[task_id] = False
    
    thread = threading.Thread(target=download_worker, args=(url, format_id, task_id, mode))
    thread.daemon = True
    thread.start()
    
    return jsonify({'task_id': task_id})

@app.route('/api/cancel', methods=['POST'])
def cancel_download():
    data = request.json
    task_id = data.get('task_id')
    if task_id in stop_tasks:
        stop_tasks[task_id] = True
        return jsonify({'status': 'cancelling'})
    return jsonify({'error': 'Task not found'}), 404

@app.route('/api/progress/<task_id>')
def get_progress(task_id):
    if task_id in downloads:
        return jsonify(downloads[task_id])
    return jsonify({'error': 'Task not found'}), 404

@app.route('/api/serve/<task_id>')
def serve_file(task_id):
    if task_id not in downloads or downloads[task_id]['status'] != 'completed':
        return jsonify({'error': 'File not ready or task not found'}), 404
    
    filename = downloads[task_id].get('filename')
    download_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'downloads')
    
    return send_from_directory(download_dir, filename, as_attachment=True)

if __name__ == '__main__':
    app.run(debug=True, port=5001, threaded=True)
