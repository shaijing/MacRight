#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA_DIR="$PROJECT_DIR/DerivedData"
PRODUCT_DIR="$DERIVED_DATA_DIR/Build/Products/Release"
BUILT_APP="$PRODUCT_DIR/MacRight.app"
INSTALLED_APP="/Applications/MacRight.app"
EXT_BUNDLE_REL="Contents/PlugIns/FinderSyncExtension.appex"
EXT_BUNDLE="$BUILT_APP/$EXT_BUNDLE_REL"

VERSION="${1#v}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "错误：未找到 xcodegen。请先安装 xcodegen，再运行 build-xcode.sh。" >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "错误：未找到可用的 xcodebuild。请先安装完整 Xcode，并运行 sudo xcode-select --switch /Applications/Xcode.app。" >&2
  exit 1
fi

if [ ! -f "$PROJECT_DIR/Sources/FinderSyncExtension/Resources/Templates/blank.docx" ] ||
   [ ! -f "$PROJECT_DIR/Sources/FinderSyncExtension/Resources/Templates/blank.xlsx" ] ||
   [ ! -f "$PROJECT_DIR/Sources/FinderSyncExtension/Resources/Templates/blank.pptx" ]; then
  echo "错误：Office 空白模板缺失。请先运行 python3 Scripts/create_templates.py。" >&2
  exit 1
fi

echo "==> Cleaning Xcode build output..."
rm -rf "$DERIVED_DATA_DIR"

echo "==> Generating Xcode project, Info.plists and entitlements..."
xcodegen generate --spec "$PROJECT_DIR/project.yml"

XCODEBUILD_ARGS=(
  -project "$PROJECT_DIR/MacRight.xcodeproj"
  -scheme MacRight
  -configuration Release
  -derivedDataPath "$DERIVED_DATA_DIR"
  -destination "generic/platform=macOS"
  -quiet
  build
  CODE_SIGNING_ALLOWED=NO
  ONLY_ACTIVE_ARCH=NO
  ARCHS=arm64\ x86_64
)

if [ -n "$VERSION" ]; then
  XCODEBUILD_ARGS+=(MARKETING_VERSION="$VERSION")
fi

echo "==> Building with xcodebuild (universal binary)..."
xcodebuild "${XCODEBUILD_ARGS[@]}"

if [ ! -d "$EXT_BUNDLE/Contents/Resources/Templates" ]; then
  echo "错误：Xcode 构建产物缺少扩展 Templates 资源目录。" >&2
  exit 1
fi

echo "==> Signing..."
codesign --force --sign - --entitlements "$PROJECT_DIR/Sources/FinderSyncExtension/FinderSyncExtension.entitlements" "$EXT_BUNDLE/Contents/MacOS/FinderSyncExtension"
codesign --force --sign - --entitlements "$PROJECT_DIR/Sources/FinderSyncExtension/FinderSyncExtension.entitlements" "$EXT_BUNDLE"
codesign --force --sign - --entitlements "$PROJECT_DIR/Sources/MacRight/MacRight.entitlements" "$BUILT_APP/Contents/MacOS/MacRight"
codesign --force --sign - --entitlements "$PROJECT_DIR/Sources/MacRight/MacRight.entitlements" "$BUILT_APP"

if [ "${CI:-}" = "true" ]; then
  echo "==> Done! (CI mode, skip local install)"
  exit 0
fi

echo "==> Installing to /Applications..."
killall MacRight 2>/dev/null || true
rm -rf "$INSTALLED_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"
codesign --force --sign - --entitlements "$PROJECT_DIR/Sources/FinderSyncExtension/FinderSyncExtension.entitlements" "$INSTALLED_APP/$EXT_BUNDLE_REL"
codesign --force --sign - --entitlements "$PROJECT_DIR/Sources/MacRight/MacRight.entitlements" "$INSTALLED_APP"

echo "==> Cleaning Xcode build dir extension to avoid duplicate registration..."
rm -rf "$BUILT_APP/$EXT_BUNDLE_REL" "$PRODUCT_DIR/FinderSyncExtension.appex"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$BUILT_APP" 2>/dev/null || true

echo "==> Registering extension..."
killall pkd 2>/dev/null || true
sleep 1
pluginkit -e use -i com.macright.app.FinderSyncExtension 2>/dev/null || true

echo "==> Done! Launching..."
open "$INSTALLED_APP"
sleep 2
pluginkit -m -p com.apple.FinderSync 2>/dev/null
