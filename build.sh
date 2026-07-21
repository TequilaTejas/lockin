#!/bin/bash
# Builds Lockin.app into build/. Run:  ./build.sh && open build/Lockin.app
#
# TCC note: ad-hoc signing (the "-" identity) changes the code's cdhash every
# rebuild, so macOS drops the Accessibility grant each time. Create a self-signed
# "Lockin Dev" cert once in Keychain Access, then:  SIGN_ID="Lockin Dev" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

# Default to the stable "Lockin Dev" identity when it exists — ad-hoc signing
# changes the cdhash every build and silently invalidates the TCC grants.
if [ -z "${SIGN_ID:-}" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q '"Lockin Dev"'; then
  SIGN_ID="Lockin Dev"
fi

swift build -c release

APP=build/Lockin.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Lockin "$APP/Contents/MacOS/Lockin"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_ID:--}" "$APP"

echo "Built $APP"
