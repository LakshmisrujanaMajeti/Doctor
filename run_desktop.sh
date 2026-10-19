#!/usr/bin/env bash
# ==============================================================================
# Sri Manakula Vinayagar Medical College & Hospital - OPD Connect
# Desktop Workstation Launcher (macOS / Linux / Windows)
# ==============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "================================================================================"
echo "   SRI MANAKULA VINAYAGAR MEDICAL COLLEGE & HOSPITAL - OPD CONNECT"
echo "   Hospital Outpatient Clinical Desktop Workstation"
echo "================================================================================"
echo ""

# 1. Check desktop_builds/OPD Connect.app
if [ -d "$DIR/desktop_builds/OPD Connect.app" ]; then
    echo "[✓] Launching Standalone Desktop App: $DIR/desktop_builds/OPD Connect.app..."
    open "$DIR/desktop_builds/OPD Connect.app"
    echo "[✓] Desktop Application running."
    exit 0
fi

# 2. Check if packaged macOS app bundle exists in dist
if [ -d "$DIR/desktop/dist/OPD Connect-darwin-arm64/OPD Connect.app" ]; then
    echo "[✓] Launching Standalone Desktop App: OPD Connect.app..."
    open "$DIR/desktop/dist/OPD Connect-darwin-arm64/OPD Connect.app"
    echo "[✓] Desktop Application running."
    exit 0
fi

# 2. Check if packaged x64 macOS app bundle exists
if [ -d "$DIR/desktop/dist/OPD Connect-darwin-x64/OPD Connect.app" ]; then
    echo "[✓] Launching Standalone Desktop App (x64): OPD Connect.app..."
    open "$DIR/desktop/dist/OPD Connect-darwin-x64/OPD Connect.app"
    echo "[✓] Desktop Application running."
    exit 0
fi

# 3. Launch via Electron in desktop directory
if command -v npm >/dev/null 2>&1 && [ -f "$DIR/desktop/package.json" ]; then
    echo "[*] Launching Clinical Desktop Workstation via Electron..."
    cd "$DIR/desktop"
    npm start
    exit 0
fi

# 4. Fallback: Local Clinical Workstation Server + Dedicated App Window
echo "[*] Starting local desktop workstation server..."
PORT=54321

# Launch using dedicated serve_web.py if available
if [ -f "$DIR/serve_web.py" ]; then
    python3 "$DIR/serve_web.py" $PORT > /dev/null 2>&1 &
    SERVER_PID=$!
else
    WEB_DIR="$DIR/web_app"
    if [ ! -f "$WEB_DIR/index.html" ]; then
        WEB_DIR="$DIR/frontend/build/web"
    fi
    cd "$WEB_DIR"
    python3 -m http.server $PORT --bind 127.0.0.1 > /dev/null 2>&1 &
    SERVER_PID=$!
    cd "$DIR"
fi

trap "kill $SERVER_PID 2>/dev/null || true" EXIT

sleep 1

# Open in standalone app window
if [ -d "/Applications/Google Chrome.app" ]; then
    echo "[✓] Opening in Chrome Standalone App Mode (Port $PORT)..."
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --app="http://127.0.0.1:$PORT" --window-size=1280,820 &
elif [ -d "/Applications/Brave Browser.app" ]; then
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --app="http://127.0.0.1:$PORT" --window-size=1280,820 &
elif [ -d "/Applications/Microsoft Edge.app" ]; then
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" --app="http://127.0.0.1:$PORT" --window-size=1280,820 &
else
    open "http://127.0.0.1:$PORT"
fi

echo "[✓] OPD Connect Desktop is running on http://127.0.0.1:$PORT"
echo "Press [Ctrl+C] to close desktop session."
wait $SERVER_PID
