#!/usr/bin/env python3
"""Waybar module for SPlayer (https://github.com/SPlayer-Dev/SPlayer).

Polls SPlayer's local control API and emits Waybar JSON output.
"""

import html
import json
import signal
import sys
import urllib.error
import urllib.request

BASE_URL = "http://127.0.0.1:25884"
MAX_LENGTH = 40


def api_get(path, timeout=1.5):
    req = urllib.request.Request(BASE_URL + path, headers={"User-Agent": "waybar-splayer/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fmt_time(ms):
    if not ms or ms < 0:
        return "0:00"
    s = int(ms // 1000)
    return f"{s // 60}:{s % 60:02d}"


def esc(text):
    return html.escape(text, quote=True)


def build_payload():
    body = api_get("/api/control/song-info")
    if body.get("code") != 200 or not body.get("data"):
        return None
    d = body["data"]
    playing = bool(d.get("playStatus"))
    title = (d.get("name") or "").strip()
    artist = ((d.get("artists") or [{}])[0].get("name") or "").strip()
    album = (d.get("album") or {}).get("name", "")
    current = d.get("currentTime") or 0
    total = d.get("duration") or 0

    if playing:
        css_class = "playing"
    else:
        css_class = "paused"
    label = f"{artist} - {title}" if artist else title
    icon = "▶ " if playing else "⏸ "
    line = icon + label
    if len(line) > MAX_LENGTH:
        line = line[: MAX_LENGTH - 1] + "…"

    tooltip = (
        f"<big><b>{esc(title)}</b></big>\n"
        f"{esc(artist)} - {esc(album)}\n"
        f"{fmt_time(current)} / {fmt_time(total)}"
    )

    return {
        "text": line,
        "alt": css_class,
        "class": css_class,
        "tooltip": tooltip,
    }


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    # One-shot mode: waybar re-executes the script on each interval tick.
    try:
        payload = build_payload()
    except (urllib.error.URLError, OSError, ValueError, KeyError):
        payload = None
    # An empty line makes waybar hide the module when SPlayer is not running.
    print(json.dumps(payload, ensure_ascii=False) if payload else "", flush=True)


if __name__ == "__main__":
    main()
