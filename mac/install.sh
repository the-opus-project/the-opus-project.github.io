#!/bin/sh
set -eu

url="${OPUS_AT_HOME_URL:-https://github.com/the-opus-project/the-opus-project.github.io/releases/download/opus-at-home-latest/OPUS-at-Home.zip}"

if [ "$(uname -s)" != Darwin ]; then
  echo "OPUS@Home runs on macOS 14 or later." >&2
  exit 1
fi
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]; then
  echo "OPUS@Home needs macOS 14 or later. This Mac has $(sw_vers -productVersion)." >&2
  exit 1
fi

dest=/Applications
if [ ! -w "$dest" ]; then
  dest="$HOME/Applications"
  mkdir -p "$dest"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading OPUS@Home..."
curl -fsSL "$url" -o "$tmp/OPUS-at-Home.zip"
ditto -x -k "$tmp/OPUS-at-Home.zip" "$tmp/unzipped"
if [ ! -d "$tmp/unzipped/OPUS@Home.app" ]; then
  echo "The download did not contain OPUS@Home.app." >&2
  exit 1
fi

pkill -x OPUSAtHome 2>/dev/null && sleep 1 || true
rm -rf "$dest/OPUS@Home.app"
ditto "$tmp/unzipped/OPUS@Home.app" "$dest/OPUS@Home.app"
xattr -dr com.apple.quarantine "$dest/OPUS@Home.app" 2>/dev/null || true

if [ "${OPUS_AT_HOME_NO_OPEN:-}" != 1 ]; then
  open "$dest/OPUS@Home.app"
fi
echo "Installed $dest/OPUS@Home.app. Click the music note in the menu bar to set it up."
