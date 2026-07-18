#!/bin/bash
# Creates a self-signed "Anchor Dev" code-signing certificate in your login
# keychain. build.sh picks it up automatically, which keeps the app's signature
# stable across rebuilds so macOS remembers your Accessibility grant.
#
# Without this, every rebuild produces a new ad-hoc signature and macOS drops
# the grant, sending you back to System Settings each time.
#
# macOS shows a password dialog when the certificate is marked trusted.
set -euo pipefail

NAME="Anchor Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$NAME\""; then
  echo "Certificate \"$NAME\" already exists. Nothing to do."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

openssl req -new -x509 -days 3650 -nodes -newkey rsa:2048 \
  -keyout "$TMP/anchor-dev.key" -out "$TMP/anchor-dev.crt" \
  -subj "/CN=$NAME" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:FALSE"

openssl pkcs12 -export -out "$TMP/anchor-dev.p12" \
  -inkey "$TMP/anchor-dev.key" -in "$TMP/anchor-dev.crt" \
  -name "$NAME" -passout pass:anchortemp

security import "$TMP/anchor-dev.p12" -k "$KEYCHAIN" -P anchortemp -T /usr/bin/codesign

echo "Marking the certificate trusted for code signing (enter your login password if asked)…"
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP/anchor-dev.crt"

security find-identity -v -p codesigning | grep "$NAME" && echo "Done. Rebuild with ./build.sh."
