document.addEventListener('DOMContentLoaded', () => {
    const urlInput = document.getElementById('url-input');
    const fetchBtn = document.getElementById('fetch-btn');
    const loadingState = document.getElementById('loading-state');
    const errorState = document.getElementById('error-state');
    const errorText = document.getElementById('error-text');
    const videoInfo = document.getElementById('video-info');
    const videoThumbnail = document.getElementById('video-thumbnail');
    const videoTitle = document.getElementById('video-title');
    const formatSelect = document.getElementById('format-select');
    const downloadBtn = document.getElementById('download-btn');
    const progressContainer = document.getElementById('progress-container');
    const progressStatus = document.getElementById('progress-status');
    const progressPercent = document.getElementById('progress-percent');
    const progressBarFill = document.getElementById('progress-bar-fill');
    const progressSpeed = document.getElementById('progress-speed');
    const progressEta = document.getElementById('progress-eta');
    const successMessage = document.getElementById('success-message');
    const downloadPlan = document.getElementById('download-plan');
    const planStepsList = document.getElementById('plan-steps-list');
    const customModal = document.getElementById('custom-modal');
    const modalTitle = document.getElementById('modal-title');
    const modalMessage = document.getElementById('modal-message');
    const modalConfirm = document.getElementById('modal-confirm');
    const modalCancel = document.getElementById('modal-cancel');
    const cancelDownloadBtn = document.getElementById('cancel-download-btn');
    const appResetBtn = document.getElementById('app-reset-btn');
    const saveDeviceBtn = document.getElementById('save-device-btn');

    let currentUrl = '';
    let videoFormats = [];
    let audioFormats = [];
    let currentMode = 'both';
    let activeTaskId = null;

    // Intersection Observer for section reveal
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, { threshold: 0.1 });

    document.querySelectorAll('section').forEach(section => {
        observer.observe(section);
    });

    const showModal = (title, message, onConfirm) => {
        modalTitle.textContent = title;
        modalMessage.textContent = message;
        customModal.classList.remove('hidden');
        
        const handleConfirm = () => {
            onConfirm();
            hideModal();
        };
        
        const hideModal = () => {
            customModal.classList.add('hidden');
            modalConfirm.removeEventListener('click', handleConfirm);
            modalCancel.removeEventListener('click', hideModal);
        };
        
        modalConfirm.addEventListener('click', handleConfirm);
        modalCancel.addEventListener('click', hideModal);
    };

    appResetBtn.addEventListener('click', () => {
        if (!activeTaskId) {
            location.reload();
            return;
        }
        
        showModal(
            'Restart App?',
            'A download is in progress. Restarting will cancel it. Are you sure?',
            () => {
                location.reload();
            }
        );
    });

    cancelDownloadBtn.addEventListener('click', () => {
        if (!activeTaskId) return;
        
        showModal(
            'Stop Download?',
            'Are you sure you want to stop this download? Any partial progress will be lost.',
            async () => {
                try {
                    const response = await fetch('/api/cancel', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ task_id: activeTaskId })
                    });
                    if (response.ok) {
                        progressStatus.textContent = 'Stopping...';
                    }
                } catch (err) {
                    console.error('Error cancelling download:', err);
                }
            }
        );
    });

    const hideAllStates = () => {
        loadingState.classList.add('hidden');
        errorState.classList.add('hidden');
        videoInfo.classList.add('hidden');
        progressContainer.classList.add('hidden');
        successMessage.classList.add('hidden');
        saveDeviceBtn.classList.add('hidden');
        downloadPlan.classList.add('hidden');
        // Don't clear activeTaskId here, let pollProgress or completed state handle it
    };

    // Warn if page is reloaded during download
    window.onbeforeunload = (e) => {
        if (activeTaskId) {
            // Standard browser confirmation - just show the warning
            const msg = 'Download in progress. If you leave, the download will be cancelled.';
            e.returnValue = msg;
            return msg;
        }
    };

    // Only cancel the download if the user actually proceeds to leave the page
    window.addEventListener('unload', () => {
        if (activeTaskId) {
            const blob = new Blob([JSON.stringify({ task_id: activeTaskId })], { type: 'application/json' });
            navigator.sendBeacon('/api/cancel', blob);
        }
    });

    const populateFormats = () => {
        formatSelect.innerHTML = '';
        const formats = currentMode === 'audio' ? audioFormats : videoFormats;
        
        if (formats.length === 0) {
            const option = document.createElement('option');
            option.textContent = 'No formats found';
            formatSelect.appendChild(option);
            return;
        }

        formats.forEach(format => {
            const option = document.createElement('option');
            option.value = format.format_id;
            
            if (currentMode === 'audio') {
                option.textContent = `${format.abr}kbps (${format.ext}) ${format.note || ''}`;
            } else {
                let label = `${format.resolution} (${format.ext})`;
                if (currentMode === 'both') {
                    label += format.needs_merge ? ' • High Quality (Merge)' : ' • Fast (Combined)';
                } else {
                    label += ' • Video Only';
                }
                option.textContent = label;
            }
            formatSelect.appendChild(option);
        });

        const modeLabels = {
            'both': 'Download Video + Audio',
            'video': 'Download Video Only',
            'audio': 'Download Audio Only'
        };
        downloadBtn.textContent = modeLabels[currentMode];
        
        updateDownloadPlan(formatSelect.value);
    };

    const updateDownloadPlan = (formatId) => {
        const formats = currentMode === 'audio' ? audioFormats : videoFormats;
        const format = formats.find(f => f.format_id === formatId);
        if (!format) return;

        downloadPlan.classList.remove('hidden');
        planStepsList.innerHTML = '';

        const steps = [];
        if (currentMode === 'both') {
            if (format.needs_merge) {
                steps.push(`Download High-Res Video (${format.resolution})`);
                steps.push(`Download Best Audio stream`);
                steps.push(`Merge Video & Audio into MP4`);
            } else {
                steps.push(`Download combined Video+Audio (${format.resolution})`);
                steps.push(`Finalize file`);
            }
        } else if (currentMode === 'video') {
            steps.push(`Download Video Stream (${format.resolution})`);
            steps.push(`Finalize Video File`);
        } else if (currentMode === 'audio') {
            steps.push(`Download Audio Stream (${format.abr}kbps)`);
            steps.push(`Finalize Audio File`);
        }

        steps.forEach((step, index) => {
            const li = document.createElement('li');
            li.innerHTML = `<span class="step-num">${index + 1}</span> ${step}`;
            planStepsList.appendChild(li);
        });
    };

    const showError = (msg) => {
        hideAllStates();
        activeTaskId = null; // Clear on error
        errorText.textContent = msg;
        errorState.classList.remove('hidden');
    };

    fetchBtn.addEventListener('click', async () => {
        const url = urlInput.value.trim();
        if (!url) return;

        currentUrl = url;
        hideAllStates();
        loadingState.classList.remove('hidden');
        
        fetchBtn.disabled = true;
        fetchBtn.textContent = 'Analyzing...';
        urlInput.disabled = true;

        try {
            const response = await fetch('/api/info', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Failed to fetch video details');
            }

            videoFormats = data.video_formats;
            audioFormats = data.audio_formats;

            // Populate UI
            videoThumbnail.src = data.thumbnail;
            videoTitle.textContent = data.title;

            hideAllStates();
            videoInfo.classList.remove('hidden');
            populateFormats();
            
        } catch (err) {
            showError(err.message);
        } finally {
            fetchBtn.disabled = false;
            fetchBtn.textContent = 'Analyze Link';
            urlInput.disabled = false;
        }
    });

    // Mode Selection Logic
    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            if (activeTaskId) return; // Prevent switching while downloading
            document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentMode = btn.dataset.mode;
            populateFormats();
        });
    });

    formatSelect.addEventListener('change', () => {
        updateDownloadPlan(formatSelect.value);
    });

    const highlightStep = (index) => {
        const steps = planStepsList.querySelectorAll('li');
        steps.forEach((step, i) => {
            if (i === index) {
                step.classList.add('active-step');
                step.classList.remove('completed-step');
            } else if (i < index) {
                step.classList.remove('active-step');
                step.classList.add('completed-step');
            } else {
                step.classList.remove('active-step');
                step.classList.remove('completed-step');
            }
        });
    };

    const formatBytes = (bytes) => {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    };

    const formatTime = (seconds) => {
        if (!seconds) return '--:--';
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    let pollInterval;

    const pollProgress = async (taskId) => {
        try {
            const response = await fetch(`/api/progress/${taskId}`);
            const data = await response.json();

            if (data.status === 'error' || data.status === 'cancelled') {
                clearInterval(pollInterval);
                activeTaskId = null;
                if (data.status === 'error') {
                    showError('Download failed: ' + data.message);
                } else {
                    progressStatus.textContent = 'Download cancelled.';
                    downloadBtn.disabled = false;
                    downloadBtn.textContent = 'Retry Download';
                }
                return;
            }

            if (data.status === 'downloading' || data.status === 'starting') {
                progressBarFill.style.width = `${data.percent}%`;
                progressPercent.textContent = `${data.percent}%`;
                progressSpeed.textContent = data.speed > 0 ? `${formatBytes(data.speed)}/s` : '';
                progressEta.textContent = data.eta > 0 ? `ETA: ${formatTime(data.eta)}` : '';
                progressStatus.textContent = data.message || 'Downloading...';
                
                // Highlight active step based on message
                if (data.message && data.message.includes('Video')) {
                    highlightStep(0);
                } else if (data.message && data.message.includes('Audio')) {
                    highlightStep(1);
                } else if (data.message && data.message.includes('Media')) {
                    highlightStep(0);
                }

                successMessage.classList.add('hidden');
            } else if (data.status === 'processing') {
                progressBarFill.style.width = '100%';
                progressPercent.textContent = '100%';
                progressStatus.textContent = data.message || 'Processing...';
                progressSpeed.textContent = '';
                progressEta.textContent = '';
                progressBarFill.classList.add('processing-anim');

                // Determine if we are merging (usually last step)
                if (currentMode === 'both') {
                    const format = videoFormats.find(f => f.format_id === formatSelect.value);
                    if (format && format.needs_merge) {
                        highlightStep(2);
                    } else {
                        highlightStep(1);
                    }
                }
            } else if (data.status === 'completed') {
                clearInterval(pollInterval);
                activeTaskId = null;
                progressBarFill.style.width = '100%';
                progressPercent.textContent = '100%';
                progressStatus.textContent = 'Done!';
                progressSpeed.textContent = '';
                progressEta.textContent = '';
                
                successMessage.classList.remove('hidden');
                saveDeviceBtn.classList.remove('hidden');
                saveDeviceBtn.href = `/api/serve/${taskId}`;
                saveDeviceBtn.setAttribute('download', data.filename || '');
                
                downloadBtn.disabled = false;
                downloadBtn.textContent = 'Download Another';
                progressBarFill.classList.remove('processing-anim');
                
                // Mark all steps as completed
                const steps = planStepsList.querySelectorAll('li');
                steps.forEach(step => {
                    step.classList.remove('active-step');
                    step.classList.add('completed-step');
                });
            }
        } catch (err) {
            console.error('Error polling progress:', err);
        }
    };

    downloadBtn.addEventListener('click', async () => {
        const formatId = formatSelect.value;
        if (!formatId || !currentUrl) return;

        downloadBtn.disabled = true;
        downloadBtn.textContent = 'Starting...';
        progressContainer.classList.remove('hidden');
        successMessage.classList.add('hidden');
        progressBarFill.style.width = '0%';
        progressPercent.textContent = '0%';
        progressStatus.textContent = 'Starting...';

        try {
            const response = await fetch('/api/download', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                    url: currentUrl, 
                    format_id: formatId,
                    mode: currentMode
                })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Failed to start download');
            }

            activeTaskId = data.task_id;
            pollInterval = setInterval(() => pollProgress(data.task_id), 1000);

        } catch (err) {
            downloadBtn.disabled = false;
            downloadBtn.textContent = 'Retry Download';
            showError(err.message);
        }
    });

    urlInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            fetchBtn.click();
        }
    });
});
