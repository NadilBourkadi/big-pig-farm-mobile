#!/usr/bin/env python3
"""Minimal server for the Big Pig Farm sprite editor.

Usage: python3 tools/sprite-editor/server.py

Serves the editor UI and handles saving sprite data back to sprite-data.json.
No external dependencies — uses only the Python standard library.
"""
import subprocess
import sys
import threading
import webbrowser
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

EDITOR_DIR = Path(__file__).resolve().parent
REPO_ROOT = EDITOR_DIR.parent.parent
SPRITE_DATA_FILE = EDITOR_DIR / "sprite-data.json"
EXPORT_SCRIPT = EDITOR_DIR.parent / "export_sprites.py"
ASSET_CATALOG = REPO_ROOT / "BigPigFarm" / "Resources" / "Assets.xcassets" / "Sprites"
MAX_BODY_BYTES = 10 * 1024 * 1024  # 10 MB — well above any realistic sprite-data.json

JSON_CATEGORIES = ["pigs", "facilities", "indicators", "patterns"]


def _save_sprite_data(body: bytes) -> None:
    """Atomically write sprite data JSON to disk."""
    tmp = SPRITE_DATA_FILE.with_suffix(".json.tmp")
    tmp.write_text(body.decode("utf-8"), encoding="utf-8")
    tmp.replace(SPRITE_DATA_FILE)


def _run_export() -> tuple[bool, str]:
    """Run export_sprites.py for all JSON-backed categories. Returns (ok, output)."""
    results = []
    for category in JSON_CATEGORIES:
        result = subprocess.run(
            [sys.executable, str(EXPORT_SCRIPT),
             "--output", str(ASSET_CATALOG),
             "--category", category],
            capture_output=True, text=True,
        )
        results.append(result.stdout)
        if result.returncode != 0:
            return False, result.stdout + result.stderr
    return True, "\n".join(results)


class EditorHandler(SimpleHTTPRequestHandler):
    """Serves static files and handles POST /save and POST /export."""

    def do_POST(self):
        if self.path == "/save":
            length = min(int(self.headers.get("Content-Length", 0)), MAX_BODY_BYTES)
            body = self.rfile.read(length)
            _save_sprite_data(body)
            self._respond(200, "Saved to sprite-data.json")
            print(f"  Saved changes to {SPRITE_DATA_FILE.name}")
        elif self.path == "/save-and-export":
            length = min(int(self.headers.get("Content-Length", 0)), MAX_BODY_BYTES)
            body = self.rfile.read(length)
            _save_sprite_data(body)
            print(f"  Saved changes to {SPRITE_DATA_FILE.name}")
            print("  Exporting to asset catalog...")
            ok, output = _run_export()
            if ok:
                self._respond(200, f"Saved and exported.\n{output}")
                print("  Export complete.")
            else:
                self._respond(500, f"Saved but export failed:\n{output}")
                print(f"  Export FAILED:\n{output}")
        else:
            self.send_error(404)

    def _respond(self, code: int, message: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(message.encode("utf-8"))

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
