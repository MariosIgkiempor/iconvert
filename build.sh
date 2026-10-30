#!/bin/zsh
# Builds build/iConvert.app (host app + embedded Finder Sync extension), ad-hoc signed.
set -e
cd "${0:A:h}"
APP=build/iConvert.app
EXT=$APP/Contents/PlugIns/FinderSync.appex
rm -rf build
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources $EXT/Contents/MacOS

cp App/Info.plist $APP/Contents/Info.plist
cp Ext/Info.plist $EXT/Contents/Info.plist

swift tools/icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o $APP/Contents/Resources/AppIcon.icns

# Universal binary (Apple silicon + Intel), macOS 13+.
for arch in arm64 x86_64; do
  T="-target $arch-apple-macos13.0"
  swiftc -O -swift-version 5 $=T -module-name iConvert App/*.swift Shared/*.swift -o build/iConvert.$arch
  swiftc -O -swift-version 5 $=T -module-name IConvertExt -application-extension -parse-as-library \
    Ext/FinderSync.swift Shared/*.swift -framework FinderSync \
    -Xlinker -e -Xlinker _NSExtensionMain -o build/FinderSync.$arch
done
lipo -create build/iConvert.arm64 build/iConvert.x86_64 -output $APP/Contents/MacOS/iConvert
lipo -create build/FinderSync.arm64 build/FinderSync.x86_64 -output $EXT/Contents/MacOS/FinderSync
rm build/iConvert.arm64 build/iConvert.x86_64 build/FinderSync.arm64 build/FinderSync.x86_64

codesign --force --sign - --entitlements Ext/Ext.entitlements $EXT
codesign --force --sign - $APP
codesign --verify --deep --strict $APP
echo "Built $APP"
