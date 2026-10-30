#!/bin/bash
# iConvert installer: downloads the latest release and enables the Finder extension.
#   curl -fsSL https://github.com/MariosIgkiempor/iconvert/releases/latest/download/install.sh | bash
set -e

REPO="MariosIgkiempor/iconvert"
DEST="$HOME/Applications/iConvert.app"
EXT_ID="dev.mario.iconvert.FinderSync"

[ "$(uname)" = "Darwin" ] || { echo "iConvert only runs on macOS."; exit 1; }

# ffmpeg is required for conversion.
if ! command -v ffmpeg >/dev/null && [ ! -x /opt/homebrew/bin/ffmpeg ] && [ ! -x /usr/local/bin/ffmpeg ]; then
  if command -v brew >/dev/null; then
    echo "Installing ffmpeg with Homebrew..."
    brew install ffmpeg
  else
    echo "Note: ffmpeg is not installed. Get it from https://brew.sh then run: brew install ffmpeg"
  fi
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading iConvert..."
curl -fsSL "https://github.com/$REPO/releases/latest/download/iConvert.zip" -o "$TMP/iConvert.zip"
ditto -x -k "$TMP/iConvert.zip" "$TMP"
xattr -dr com.apple.quarantine "$TMP/iConvert.app" 2>/dev/null || true

pkill -x iConvert 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
mv "$TMP/iConvert.app" "$DEST"

pluginkit -a "$DEST/Contents/PlugIns/FinderSync.appex"
pluginkit -e use -i "$EXT_ID"
open "$DEST"
killall Finder

echo "Installed. Right-click an audio file in Finder > Convert to."
echo "If the menu doesn't appear: System Settings > Login Items & Extensions > Finder, enable iConvert."
