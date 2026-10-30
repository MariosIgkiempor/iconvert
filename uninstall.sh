#!/bin/bash
# Removes iConvert and its Finder extension.
#   curl -fsSL https://github.com/MariosIgkiempor/iconvert/releases/latest/download/uninstall.sh | bash
pkill -x iConvert 2>/dev/null
pluginkit -r "$HOME/Applications/iConvert.app/Contents/PlugIns/FinderSync.appex" 2>/dev/null
rm -rf "$HOME/Applications/iConvert.app"
killall Finder
echo "Removed."
