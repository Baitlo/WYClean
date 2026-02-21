#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/WYClean.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
PKG_ROOT="$BUILD_DIR/pkgroot"
APP_NAME="WYClean.app"
IDENTIFIER="com.wyclean.app"
PKG_PATH="$BUILD_DIR/WYClean-installer.pkg"

rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR" "$PKG_ROOT/Applications"

xcodebuild \
  -project "$PROJECT_ROOT/WYClean.xcodeproj" \
  -scheme WYClean \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME" "$PKG_ROOT/Applications/$APP_NAME"

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "$IDENTIFIER" \
  --version "1.0.0" \
  --install-location "/" \
  "$PKG_PATH"

echo "Installer generated: $PKG_PATH"
