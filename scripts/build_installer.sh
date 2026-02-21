#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/WYClean.xcarchive"
APP_NAME="WYClean.app"
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
IDENTIFIER="com.wyclean.app"
PKG_PATH="$BUILD_DIR/WYClean-installer.pkg"

# 可选：通过环境变量传入签名证书名称
#   export APP_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export INSTALLER_SIGN_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"

require_full_xcode() {
  if ! command -v xcode-select >/dev/null 2>&1; then
    echo "[ERROR] xcode-select 未找到。请先安装 Xcode。" >&2
    exit 1
  fi

  local developer_dir
  developer_dir="$(xcode-select -p 2>/dev/null || true)"

  if [[ -z "$developer_dir" ]]; then
    echo "[ERROR] 当前没有可用的开发者目录，请先安装并初始化 Xcode。" >&2
    exit 1
  fi

  if [[ "$developer_dir" == *"CommandLineTools"* ]]; then
    cat >&2 <<MSG
[ERROR] 检测到当前激活的是 Command Line Tools：
  $developer_dir
构建 macOS App Archive 需要完整 Xcode（含 xcodebuild archive 支持）。
请执行：
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
然后重新运行本脚本。
MSG
    exit 1
  fi

  for tool in xcodebuild pkgbuild pkgutil; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "[ERROR] $tool 未找到，请确认完整 Xcode 已安装并生效。" >&2
      exit 1
    fi
  done
}

sign_app_if_needed() {
  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    echo "[INFO] 未提供 APP_SIGN_IDENTITY，跳过 .app 手动签名。"
    return
  fi

  if ! command -v codesign >/dev/null 2>&1; then
    echo "[ERROR] 需要 codesign 才能签名 .app。" >&2
    exit 1
  fi

  echo "[INFO] 使用 APP_SIGN_IDENTITY 签名应用：$APP_SIGN_IDENTITY"
  codesign --force --options runtime --timestamp --deep --sign "$APP_SIGN_IDENTITY" "$APP_PATH"
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
}

build_installer_pkg() {
  local pkgbuild_args=(
    --component "$APP_PATH"
    --identifier "$IDENTIFIER"
    --version "1.0.0"
    --install-location "/Applications"
  )

  if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
    echo "[INFO] 使用 INSTALLER_SIGN_IDENTITY 签名安装包：$INSTALLER_SIGN_IDENTITY"
    pkgbuild_args+=(--sign "$INSTALLER_SIGN_IDENTITY")
  else
    echo "[WARN] 未提供 INSTALLER_SIGN_IDENTITY，生成未签名 pkg（部分机器可能出现安装拦截或泛化错误提示）。"
  fi

  pkgbuild "${pkgbuild_args[@]}" "$PKG_PATH"
}

require_full_xcode

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[INFO] 开始 archive..."
xcodebuild \
  -project "$PROJECT_ROOT/WYClean.xcodeproj" \
  -scheme WYClean \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

if [[ ! -d "$APP_PATH" ]]; then
  echo "[ERROR] 未找到归档产物：$APP_PATH" >&2
  exit 1
fi

sign_app_if_needed
build_installer_pkg

echo "[INFO] 安装包签名信息："
pkgutil --check-signature "$PKG_PATH" || true

echo "Installer generated: $PKG_PATH"
