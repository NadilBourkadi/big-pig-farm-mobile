#!/usr/bin/env python3
"""Set 'What to Test' notes on a TestFlight build via App Store Connect API.

Required environment variables:
    ASC_KEY_PATH    — path to the .p8 private key
    ASC_KEY_ID      — App Store Connect API key ID
    ASC_ISSUER_ID   — App Store Connect issuer ID
    BUILD_NUMBER    — the build number to annotate
    NOTES           — the "What to Test" text
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error

try:
    import jwt
except ImportError:
    sys.exit("PyJWT not installed. Run: pip3 install PyJWT cryptography")


def create_token():
    key_path = os.path.expanduser(os.environ["ASC_KEY_PATH"])
    with open(key_path) as f:
        private_key = f.read()

    now = int(time.time())
    return jwt.encode(
        {
            "iss": os.environ["ASC_ISSUER_ID"],
            "iat": now,
            "exp": now + 1200,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"]},
    )


def api_request(url, token, method="GET", data=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read())


def find_build(token, build_number):
    """Poll for the build to appear in App Store Connect (processing delay)."""
    base = "https://api.appstoreconnect.apple.com/v1"
    url = f"{base}/builds?filter[buildNumber]={build_number}&limit=5"

    for attempt in range(18):  # 3 minutes max
        try:
            data = api_request(url, token)
            if data["data"]:
                return data["data"][0]["id"]
        except urllib.error.HTTPError as e:
            print(f"  Attempt {attempt + 1}: HTTP {e.code}", flush=True)
        time.sleep(10)

    return None


def set_notes(token, build_id, notes):
    base = "https://api.appstoreconnect.apple.com/v1"

    # Check for existing localization
    url = f"{base}/builds/{build_id}/betaBuildLocalizations"
    localizations = api_request(url, token)

    if localizations["data"]:
        loc_id = localizations["data"][0]["id"]
        api_request(
            f"{base}/betaBuildLocalizations/{loc_id}",
            token,
            method="PATCH",
            data={
                "data": {
                    "id": loc_id,
                    "type": "betaBuildLocalizations",
                    "attributes": {"whatsNew": notes},
                }
            },
        )
    else:
        api_request(
            f"{base}/betaBuildLocalizations",
            token,
            method="POST",
            data={
                "data": {
                    "type": "betaBuildLocalizations",
                    "attributes": {"locale": "en-GB", "whatsNew": notes},
                    "relationships": {
                        "build": {
                            "data": {"id": build_id, "type": "builds"}
                        }
                    },
                }
            },
        )


def main():
    build_number = os.environ["BUILD_NUMBER"]
    notes = os.environ["NOTES"]

    print(f"Looking for build #{build_number}...", flush=True)
    token = create_token()

    build_id = find_build(token, build_number)
    if not build_id:
        print("WARNING: Build not found after 3 minutes. Skipping notes.")
        return

    print(f"Found build {build_id}. Setting notes...", flush=True)
    set_notes(token, build_id, notes)
    print(f"Done. Notes set to:\n{notes}")


if __name__ == "__main__":
    main()
