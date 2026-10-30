#!/bin/zsh
# Builds from source and installs iConvert to ~/Applications and enables its Finder extension.
set -e
cd "${0:A:h}"
./build.sh

DEST=$HOME/Applications/iConvert.app
pkill -x iConvert 2>/dev/null || true
mkdir -p $HOME/Applications
rm -rf "$DEST"
cp -R build/iConvert.app "$DEST"

# Remove the old Quick Action versions, if present.
rm -rf "$HOME/Library/Services/Convert to MP3.workflow" "$HOME/Library/Services/Convert to WAV.workflow" "$HOME/Library/Services/Convert Audio.workflow"

pluginkit -a "$DEST/Contents/PlugIns/FinderSync.appex"
pluginkit -e use -i dev.mario.iconvert.FinderSync
open "$DEST"
killall Finder
echo "Installed. Right-click an audio file > Convert to."
