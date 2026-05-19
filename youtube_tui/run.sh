#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "======================================"
echo " Starting Void-Archive TUI "
echo "======================================"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required but was not found."
    exit 1
fi

if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "Activating environment..."
source venv/bin/activate

echo "Installing requirements..."
pip install -r requirements.txt > /dev/null

echo "Launching terminal app..."
python3 app.py
