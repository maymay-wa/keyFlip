#!/bin/bash
# Build, sign, notarize and package KeyFlip for the GitHub release page.
#
# The goal is a download that Just Works: a notarized, stapled DMG that opens
# without a Gatekeeper warning, and an app inside it that launches on the first
# double-click. Both the app *and* the disk image are notarized and stapled --
# stapling only the app leaves the .dmg itself flagged as "Unnotarized
# Developer ID" once it has been downloaded.
#
#   scripts/package.sh                 # sign + notarize + package into dist/
#   scripts/package.sh --release       # ...and stage a draft GitHub release
#
# Signing identity is auto-detected from the keychain. Overrides:
#   SIGN_IDENTITY="Developer ID Application: ..."   # or "-" for ad-hoc
#   NOTARY_PROFILE=keyflip                          # empty to skip notarizing
# See README "Releasing" for the one-time notarytool setup.
set -euo pipefail

cd "$(dirname "$0")/.."

MAKE_RELEASE=0
for arg in "$@"; do
    case "$arg" in
        --release) MAKE_RELEASE=1 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Sources/KeyFlip/Info.plist)
DIST=dist
APP=build/Build/Products/Release/KeyFlip.app
VOLNAME="KeyFlip $VERSION"
MOUNT="/Volumes/$VOLNAME"
DMG="$DIST/KeyFlip-$VERSION.dmg"
ZIP="$DIST/KeyFlip-$VERSION.zip"

# Auto-detect a Developer ID unless one was passed in. Ad-hoc ("-") still
# produces a working DMG, but every user has to clear quarantine by hand.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
NOTARY_PROFILE="${NOTARY_PROFILE-keyflip}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    NOTARY_PROFILE=""
    echo "!! No Developer ID found -- building an ad-hoc signed, UNNOTARIZED app."
    echo "!! Users will have to right-click -> Open, or run: xattr -cr /Applications/KeyFlip.app"
fi

notarize() {  # notarize <path-to-submit> ; staples separately
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait \
        | sed 's/^/     /'
}

echo "==> Building KeyFlip $VERSION (Release)"
rm -rf "$APP"
xcodebuild -project KeyFlip.xcodeproj -scheme KeyFlip -configuration Release \
    -derivedDataPath build build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO | tail -3

echo "==> Signing app ($SIGN_IDENTITY)"
# Sign inside-out. There is no nested code today, but a future framework or
# helper would otherwise be signed over by the outer signature and rejected.
while IFS= read -r nested; do
    codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$nested"
done < <(find "$APP/Contents" -maxdepth 3 \( -name '*.framework' -o -name '*.dylib' -o -name '*.appex' \) 2>/dev/null)
codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=1 "$APP"

if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "==> Notarizing app (profile: $NOTARY_PROFILE)"
    ditto -c -k --keepParent "$APP" "$TMPDIR/KeyFlip-notarize.zip"
    notarize "$TMPDIR/KeyFlip-notarize.zip"
    rm -f "$TMPDIR/KeyFlip-notarize.zip"
    xcrun stapler staple "$APP"
fi

rm -rf "$DIST"
mkdir -p "$DIST/staging/.background"
cp -R "$APP" "$DIST/staging/"
ln -s /Applications "$DIST/staging/Applications"
cp scripts/dmg/background.tiff "$DIST/staging/.background/"
cp scripts/dmg/VolumeIcon.icns "$DIST/staging/.VolumeIcon.icns"

echo "==> Creating DMG"
hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
hdiutil create -volname "$VOLNAME" -srcfolder "$DIST/staging" -fs HFS+ \
    -format UDRW -ov "$DIST/rw.dmg" -quiet
hdiutil attach "$DIST/rw.dmg" -readwrite -noverify -noautoopen -quiet

# Lay the window out so the drag target is obvious. Cosmetic only: if Finder
# automation is unavailable (e.g. on a CI box) the DMG is still perfectly usable.
if ! osascript - "$VOLNAME" <<'APPLESCRIPT'
on run argv
    set volName to item 1 of argv
    tell application "Finder"
        tell disk volName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {240, 140, 900, 540}
            set opts to the icon view options of container window
            set arrangement of opts to not arranged
            set icon size of opts to 128
            set text size of opts to 12
            set label position of opts to bottom
            set background picture of opts to file ".background:background.tiff"
            set position of item "KeyFlip.app" of container window to {170, 185}
            set position of item "Applications" of container window to {490, 185}
            close
            open
            -- Finder restores a cached window state for a volume of this name on
            -- reopen, so the bounds have to be re-asserted before they are saved.
            set the bounds of container window to {240, 140, 900, 540}
            update without registering applications
            delay 3
            close
        end tell
    end tell
end run
APPLESCRIPT
then
    echo "!! Finder layout failed -- shipping a plain DMG window."
fi

SetFile -a C "$MOUNT" 2>/dev/null || true   # use .VolumeIcon.icns for the mounted disk
sync
for _ in 1 2 3 4 5; do hdiutil detach "$MOUNT" -quiet && break || sleep 2; done

hdiutil convert "$DIST/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet
rm -f "$DIST/rw.dmg"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    echo "==> Signing DMG"
    codesign --force --timestamp -s "$SIGN_IDENTITY" "$DMG"
fi
if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "==> Notarizing DMG (profile: $NOTARY_PROFILE)"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
fi

echo "==> Creating zip"
ditto -c -k --keepParent "$DIST/staging/KeyFlip.app" "$ZIP"
rm -rf "$DIST/staging"

echo "==> Verifying"
if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun stapler validate "$DMG"
    spctl -a -vv -t open --context context:primary-signature "$DMG"
    hdiutil attach "$DMG" -readonly -nobrowse -quiet -mountpoint "$DIST/verify"
    spctl -a -vv -t exec "$DIST/verify/KeyFlip.app"
    xcrun stapler validate "$DIST/verify/KeyFlip.app"
    hdiutil detach "$DIST/verify" -quiet
fi
(cd "$DIST" && shasum -a 256 ./*.dmg ./*.zip | sed 's|\./||' > SHA256SUMS)

echo "==> Done:"
ls -lh "$DIST"
cat "$DIST/SHA256SUMS"

if [[ "$MAKE_RELEASE" == "1" ]]; then
    TAG="v$VERSION"
    echo "==> Staging draft GitHub release $TAG"
    git rev-parse "$TAG" >/dev/null 2>&1 || git tag -a "$TAG" -m "KeyFlip $VERSION"
    git push origin "$TAG"
    sed "s/__VERSION__/$VERSION/g" scripts/release-notes.md > "$DIST/release-notes.md"
    # A version-less copy gives README and the web a permanent download URL:
    # https://github.com/maymay-wa/keyFlip/releases/latest/download/KeyFlip.dmg
    cp "$DMG" "$DIST/KeyFlip.dmg"
    gh release create "$TAG" "$DMG" "$DIST/KeyFlip.dmg" "$ZIP" "$DIST/SHA256SUMS" \
        --draft --title "KeyFlip $VERSION" --notes-file "$DIST/release-notes.md"
    echo "Draft created -- review it, then publish with: gh release edit $TAG --draft=false"
fi
