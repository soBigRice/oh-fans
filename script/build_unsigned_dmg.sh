#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/iFans.xcodeproj"
SCHEME="iFans"
CONFIGURATION="Release"
APP_NAME="oh fans"
APP_BUNDLE_NAME="$APP_NAME.app"
README_SOURCE="$ROOT_DIR/docs/README_如果打不开请看这里.md"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedDataUnsignedDMG"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_SOURCE_PATH="$PRODUCTS_DIR/$APP_BUNDLE_NAME"
STAGING_DIR="$ROOT_DIR/build/dmg/$APP_NAME"
OUTPUT_DIR="$ROOT_DIR/build/release"

if [[ ! -f "$README_SOURCE" ]]; then
  echo "missing release README: $README_SOURCE" >&2
  exit 1
fi

echo "Building unsigned $CONFIGURATION app..."
xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$APP_SOURCE_PATH" ]]; then
  echo "app bundle not found: $APP_SOURCE_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_SOURCE_PATH/Contents/Info.plist"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
APP_BUILD="$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
DMG_NAME="oh-fans-${APP_VERSION}-${APP_BUILD}-unsigned.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
VOLUME_NAME="oh fans ${APP_VERSION}"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"

ditto "$APP_SOURCE_PATH" "$STAGING_DIR/$APP_BUNDLE_NAME"
cp "$README_SOURCE" "$STAGING_DIR/README_如果打不开请看这里.md"
ln -s /Applications "$STAGING_DIR/Applications"

# Drop local xattrs so the packaged app starts from a clean build artifact.
xattr -cr "$STAGING_DIR/$APP_BUNDLE_NAME" || true

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "Unsigned DMG created:"
echo "  $DMG_PATH"
