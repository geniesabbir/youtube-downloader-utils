#!/bin/bash
set -euo pipefail

# Navigate to script directory
cd "$(dirname "$0")"

echo "======================================"
echo " Starting Void-Downloader Web UI "
echo "======================================"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "First time setup: Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate venv
echo "Activating environment..."
source venv/bin/activate

# Install requirements
echo "Checking requirements..."
pip install -r requirements.txt > /dev/null 2>&1

# Run the app
echo "======================================"
echo " Server is starting... "
echo " Please open http://localhost:5001 in your browser! "
echo " (Press Ctrl+C to stop the server) "
echo "======================================"
python3 app.py
