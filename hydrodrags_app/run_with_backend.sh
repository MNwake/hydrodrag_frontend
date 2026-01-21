#!/bin/bash

# Script to run Flutter app with backend URL configured for physical devices

# Find your local IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    IP=$(hostname -I | awk '{print $1}')
else
    echo "Unsupported OS. Please set IP manually."
    exit 1
fi

if [ -z "$IP" ]; then
    echo "Could not detect IP address. Please set it manually:"
    echo "flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000"
    exit 1
fi

echo "Detected IP address: $IP"
echo "Running Flutter app with API_BASE_URL=http://$IP:8000"
echo ""
echo "Make sure your FastAPI backend is running on port 8000!"
echo "Press Ctrl+C to cancel, or wait 3 seconds..."
sleep 3

flutter run --dart-define=API_BASE_URL=http://$IP:8000 "$@"
