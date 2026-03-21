#!/usr/bin/env python3
"""Minimal server for the Big Pig Farm sprite editor.

Usage: python3 tools/sprite-editor/server.py

Serves the editor UI and handles saving sprite data back to sprite-data.json.
No external dependencies — uses only the Python standard library.
"""
import sys
import threading
import webbrowser
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

EDITOR_DIR = Path(__file__).resolve().parent
SPRITE_DATA_FILE = EDITOR_DIR / "sprite-data.json"
MAX_BODY_BYTES = 10 * 1024 * 1024  # 10 MB — well above any realistic sprite-data.json


class EditorHandler(SimpleHTTPRequestHandler):
    """Serves static files and handles POST /save."""

    def do_POST(self):
        if self.path == "/save":
            length = min(int(self.headers.get("Content-Length", 0)), MAX_BODY_BYTES)
            body = self.rfile.read(length)
            # Atomic write: tmp file + rename to avoid corruption on crash
            tmp = SPRITE_DATA_FILE.with_suffix(".json.tmp")
            tmp.write_text(body.decode("utf-8"), encoding="utf-8")
            tmp.replace(SPRITE_DATA_FILE)
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b"Saved to sprite-data.json")
            print(f"  Saved changes to {SPRITE_DATA_FILE.name}")
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        # Suppress successful GET noise; still print errors
        if args and str(args[1]) not in ("200", "304"):
            super().log_message(format, *args)


def main():
    if not SPRITE_DATA_FILE.exists():
        print(f"Error: {SPRITE_DATA_FILE} not found.")
        print("Run the sprite data seed step first.")
        sys.exit(1)

    handler = partial(EditorHandler, directory=str(EDITOR_DIR))
    server = HTTPServer(("127.0.0.1", 0), handler)
    port = server.server_address[1]
    url = f"http://127.0.0.1:{port}/index.html"

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    print(f"Sprite editor running at {url}")
    print("Press Ctrl+C to stop.")
    webbrowser.open(url)

    try:
        thread.join()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        server.shutdown()


if __name__ == "__main__":
    main()
