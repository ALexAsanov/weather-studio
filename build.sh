#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="build/Weather Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 -framework AppKit -framework SwiftUI -framework CoreGraphics Sources/*.swift -o "$APP/Contents/MacOS/WeatherStudio"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/WeatherStudio" --self-test
