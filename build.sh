#!/bin/bash
# Builds Anchor.app into build/. Run:  ./build.sh && open build/Anchor.app
#
# TCC note: ad-hoc signing (the "-" identity) changes the code's cdhash every
# rebuild, so macOS drops the Accessibility grant each time. Create a self-signed
# "Anchor Dev" cert once in Keychain Access, then:  SIGN_ID="Anchor Dev" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

# Default to the stable "Anchor Dev" identity when it exists — ad-hoc signing
# changes the cdhash every build and silently invalidates the TCC grants.
if [ -z "${SIGN_ID:-}" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q '"Anchor Dev"'; then
  SIGN_ID="Anchor Dev"
fi

swift build -c release

APP=build/Anchor.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Anchor "$APP/Contents/MacOS/Anchor"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_ID:--}" "$APP"

echo "Built $APP"
