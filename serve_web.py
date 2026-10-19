#!/usr/bin/env python3
"""
SMVMCH OPD Connect - High-Performance Clinical Workstation Web Server
Self-contained static server with WASM MIME handling, SPA fallback,
and Cross-Origin Isolation headers for CanvasKit & SQLite/Supabase web workers.
"""

import os
import sys
import mimetypes
import http.server
import socketserver

DEFAULT_PORT = 54321
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Resolution order for compiled web application
CANDIDATES = [
    os.path.join(BASE_DIR, "web_app"),
    os.path.join(BASE_DIR, "frontend", "build", "web"),
    os.path.join(BASE_DIR, "desktop", "web"),
]

TARGET_DIR = None
for candidate in CANDIDATES:
    if os.path.isdir(candidate) and os.path.isfile(os.path.join(candidate, "index.html")):
        TARGET_DIR = candidate
        break

if not TARGET_DIR:
    print("=" * 80)
    print(" [ERROR] Compiled web application not found!")
    print(" Checked the following locations:")
    for c in CANDIDATES:
        print(f"   - {c} (index.html missing: {not os.path.isfile(os.path.join(c, 'index.html'))})")
    print("=" * 80)
    sys.exit(1)

# Ensure proper MIME types for Flutter CanvasKit WebAssembly & ES modules
mimetypes.init()
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("text/css", ".css")
mimetypes.add_type("image/svg+xml", ".svg")
mimetypes.add_type("image/png", ".png")
mimetypes.add_type("font/woff2", ".woff2")
mimetypes.add_type("font/woff", ".woff")
mimetypes.add_type("font/ttf", ".ttf")


class ClinicalSPARequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=TARGET_DIR, **kwargs)

    def end_headers(self):
        # Cross-Origin Isolation headers required for CanvasKit WASM threads
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def _resolve_spa_path(self):
        raw_path = self.path.split("?")[0].lstrip("/")
        if not raw_path:
            self.path = "/index.html"
            return
        disk_path = os.path.join(TARGET_DIR, raw_path)
        if not os.path.exists(disk_path) or os.path.isdir(disk_path):
            self.path = "/index.html"

    def do_GET(self):
        self._resolve_spa_path()
        return super().do_GET()

    def do_HEAD(self):
        self._resolve_spa_path()
        return super().do_HEAD()

    def log_message(self, format, *args):
        # Suppress routine GET logging unless error occurs
        if args and str(args[1]).startswith(('4', '5')):
            super().log_message(format, *args)


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def run_server():
    print("=" * 80)
    print("   SRI MANAKULA VINAYAGAR MEDICAL COLLEGE & HOSPITAL - OPD CONNECT")
    print("   Clinical Workstation HTTP Server (WASM & CanvasKit Enabled)")
    print("=" * 80)
    print(f" [*] Serving Root Directory: {TARGET_DIR}")
    print(f" [*] Workstation Endpoint  : http://127.0.0.1:{PORT}")
    print("=" * 80)

    try:
        with ReusableTCPServer(("127.0.0.1", PORT), ClinicalSPARequestHandler) as httpd:
            httpd.serve_forever()
    except OSError as e:
        if "Address already in use" in str(e) or getattr(e, "winerror", None) == 10048:
            print(f" [!] Port {PORT} is already in use by another OPD Connect instance.")
            print(f" [✓] Existing session is active at: http://127.0.0.1:{PORT}")
            sys.exit(0)
        else:
            raise e


if __name__ == "__main__":
    run_server()
