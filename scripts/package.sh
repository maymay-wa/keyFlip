#!/bin/bash
# Build a Release KeyFlip.app and package it as a DMG and a zip in dist/.
#
# Ad-hoc signed by default (users must right-click -> Open on first launch).
# For a notarized, zero-friction build, pass a Developer ID identity and a
# notarytool keychain profile (see README "Releasing"):
#   SIGN_IDENTITY="Developer ID Application: ..." NOTARY_PROFILE=keyflip scripts/package.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Sources/KeyFlip/Info.plist)
DIST=dist
APP=build/Build/Products/Release/KeyFlip.app

echo "==> Building KeyFlip $VERSION (Release)"
xcodebuild -project KeyFlip.xcodeproj -scheme KeyFlip -configuration Release \
    -derivedDataPath build build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO | tail -3

echo "==> Signing (identity: $SIGN_IDENTITY)"
codesign --force --deep --options runtime --timestamp -s "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

rm -rf "$DIST"
mkdir -p "$DIST"

if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "==> Notarizing (profile: $NOTARY_PROFILE)"
    ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
    xcrun notarytool submit "$DIST/notarize.zip" \
        --keychain-profile "$NOTARY_PROFILE" --wait
    rm "$DIST/notarize.zip"
    xcrun stapler staple "$APP"
fi

mkdir -p "$DIST/staging"
cp -R "$APP" "$DIST/staging/"
ln -s /Applications "$DIST/staging/Applications"

echo "==> Creating DMG"
hdiutil create -volname "KeyFlip $VERSION" -srcfolder "$DIST/staging" \
    -ov -format UDZO "$DIST/KeyFlip-$VERSION.dmg" -quiet
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign -s "$SIGN_IDENTITY" --timestamp "$DIST/KeyFlip-$VERSION.dmg"
fi

echo "==> Creating zip"
ditto -c -k --keepParent "$DIST/staging/KeyFlip.app" "$DIST/KeyFlip-$VERSION.zip"

rm -rf "$DIST/staging"
if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "==> Gatekeeper check"
    spctl -a -vv "$APP"
fi
echo "==> Done:"
ls -lh "$DIST"
